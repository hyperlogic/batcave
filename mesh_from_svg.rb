#!/opt/local/bin/ruby

require 'rexml/document'
require 'optparse'
require 'ostruct'
require 'matrix'

$debug = false

Path = Struct.new :positions, :name

module MeshFromSVG

  # transforms a pos by the given xform represented as a 3x3 Matrix
  def self.transform_pos pos, xform
    col = Matrix.column_vector([pos[0], pos[1], 1])
    col = xform * col
    [col[0,0], col[1,0]]
  end

  # Converts a path REXML::Element into a new Element with absolute commands &
  # coordinates in the global coordinate frame.
  # these new paths are added to the global $paths varaible
  def self.transform_path path, g, parent_xform
    if $debug
      $log.puts "path id = #{path.attributes['id']}"
    end

    # concatinate matrices
    if path.attributes['transform']
      xform = parent_xform * get_xform_from_attr(path.attributes['transform'])
    else
      xform = parent_xform
    end

    if $debug
      $log.puts "splitting path"
      $log.puts "d = #{path.attributes['d']}"
    end

    command_pattern = /[mMlLhHvVCczZaAQqTt]/
    tokens = path.attributes['d'].split(/[ ,]/)
    # puts "tokens = #{tokens.inspect}"

    positions = []

    while tokens.size > 0 do
      token = tokens.shift
      case token
      when "M"
        # moveto absolute
        while !(tokens[0] =~ command_pattern) and tokens.size > 0 do
          x = tokens.shift.to_f
          y = tokens.shift.to_f
          # puts "(#{x}, #{y})"
          positions << [x, y]
        end
      when "m"
        # moveto relative
        prev = [0, 0]
        while !(tokens[0] =~ command_pattern) and tokens.size > 0 do
          x = tokens.shift.to_f
          y = tokens.shift.to_f
          # puts "(#{x}, #{y})"
          prev = [x + prev[0], y + prev[1]]
          positions << prev
        end
      when "L"
        # lineto absolute
        while !(tokens[0] =~ command_pattern) and tokens.size > 0 do
          x = tokens.shift.to_f
          y = tokens.shift.to_f
          # puts "(#{x}, #{y})"
          positions << [x, y]
        end
      when /[zZ]/
        tokens = []
      else
        raise "ERROR: unsupprted token \"#{token}\""
      end
    end

    positions.map! {|pos| transform_pos(pos, xform)}

    # add it to the global path array
    $paths << Path.new(positions, g.attributes['inkscape:label'])
  end

  # parses a transform attribute string and 
  # returns it as a 3x3 Matrix
  def self.get_xform_from_attr str
    split = str.split(/[\(\),]/)
    case split[0]
    when "matrix"
      Matrix[[split[1].to_f, split[3].to_f, split[5].to_f],
             [split[2].to_f, split[4].to_f, split[6].to_f],
             [0,0,1]]
    when "translate"
      Matrix[[1, 0, split[1].to_f], [0, 1, split[2].to_f], [0,0,1]]
    else
      raise "unsupported transform attr #{split[0]}"
    end
  end

  # recursivly traverse this group node finding sub-groups and sub-paths
  def self.transform_group g, parent_xform
    if $debug
      $log.puts "group id = #{g.attributes['id']}"
    end

    # concatinate matricies
    if g.attributes['transform']
      xform = parent_xform * get_xform_from_attr(g.attributes['transform'])
    else
      xform = parent_xform
    end

    # traverse each child group & path
    g.elements.each('g') do |child|
      transform_group child, xform
    end
    g.elements.each('path') do |child|
      transform_path child, g, xform
    end
  end

  # only works on paths with absolute commands and no transforms
  def self.positions_from_path(path)
    result = []
    path.attributes['d'].split.each do |token|
      case token
      when /[mlzhvcs]/
        raise "positions_from_path only works on absolute commands"
      when /[MLZHVCS]/
        nil
      else
        pos = token.split(',').map {|num| num.to_f}
        result << pos
      end
    end
    result
  end

  def self.positions_to_path(path, positions)
    i = 0
    new_d = path.attributes['d'].split.map do |token|
      case token
      when /[mlzhvcs]/
        raise "positions_from_path only works on absolute commands"
      when /[MLZHVCS]/
        token
      else
        r = "#{positions[i][0].to_s},#{positions[i][1].to_s}"
        i += 1
        r
      end
    end
    path.attributes['d'] = new_d.join(" ")
  end

  # recursivly traverse the document
  def self.transform_doc doc

    # will hold every path encountered when travesing the SVG hierarchy
    $paths = []

    doc.elements.each('svg') do |svg|

      # traverse each group
      svg.elements.each('g') do |g|
        transform_group g, Matrix.identity(3)
      end

      # traverse each path
      svg.elements.each('path') do |path|
        transform_path path, Matrix.identity(3)
      end
    end
  end

  def self.build_paths svg_file

    $log = STDOUT

    # read svg-xml file
    doc = nil
    File.open(svg_file, "r") do |f|
      doc = REXML::Document.new f
    end

    # traverse document filling up $paths with each outline
    transform_doc doc

    $paths
  end

end

paths = MeshFromSVG.build_paths ARGV[0]

puts "-- exported from #{ARGV[0]}"

puts "Level {"
paths.each do |path|
  prev = nil
  path.positions.each do |point|
    if prev
      puts "    { #{prev[0]}, #{prev[1]}, #{point[0]}, #{point[1]}, \"#{path.name}\" },"
    end
    prev = point
  end
end

puts "}"
