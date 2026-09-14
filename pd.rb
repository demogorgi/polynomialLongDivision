#!/usr/bin/env ruby
# frozen_string_literal: true

# Polynomial long division, worked out step by step.
#
# The division is laid out in the Central European ("schriftliche Division")
# notation that is taught in German-speaking classrooms:
#
#     (dividend) : (divisor) = quotient
#   -(subtrahend)
#   -------------------------
#     remainder
#     ...
#
# Coefficients live either in a prime field Z/pZ or in the rational numbers.
#
# Usage:
#   ruby pd.rb "3,0,0,1,1" "4,0,3" 5 x
#   ruby pd.rb --help
#
# by Uwe Gotzes

require "optparse"

# --------------------------------------------------------------------------
# Coefficient domains
# --------------------------------------------------------------------------

# Common behaviour of all coefficient domains. A field knows how to turn user
# input into a coefficient, how to do arithmetic in it, and how to render its
# elements for the shell and for LaTeX.
#
# Subclasses only need to supply +parse+, +normalize+, +inverse+ and +name+;
# everything else is expressed in terms of those.
class Field
  # Builds the field the user asked for on the command line: characteristic 0
  # selects the rational numbers, a prime p selects Z/pZ.
  #
  # 1 is accepted as well, but only because earlier versions of this script
  # used it for "not a finite field". There is no field of characteristic 1:
  # char = 1 means 1 = 0, which leaves the zero ring, and that is not a field.
  LEGACY_RATIONAL_ALIAS = 1

  def self.build(characteristic)
    case characteristic
    when 0, LEGACY_RATIONAL_ALIAS then RationalField.new
    else
      unless PrimeOrderField.prime?(characteristic)
        raise ArgumentError,
              "characteristic must be 0 (rational numbers) or a prime number, got #{characteristic}"
      end

      PrimeOrderField.new(characteristic)
    end
  end

  def zero = 0
  def zero?(value) = value.zero?
  def one?(value) = value == 1

  # Both of these answer a question about rendering, not about algebra. Z/pZ is
  # not an ordered field, so none of its elements is "negative" and none has a
  # magnitude; there the answer is simply that no minus sign is ever printed.
  def prints_with_minus?(_value) = false
  def without_sign(value) = value

  # How a coefficient looks when it stands in front of a variable. Only the
  # rational numbers need to deviate from the plain rendering.
  def coefficient_factor_to_s(value) = coefficient_to_s(value)

  def add(a, b) = normalize(a + b)
  def subtract(a, b) = normalize(a - b)
  def multiply(a, b) = normalize(a * b)
  def negate(a) = normalize(-a)

  # Two coefficient fields are the same when they are the same kind of field
  # and agree in their characteristic. The characteristic alone would not be
  # enough in general - Q and R share it - so the class takes part in the
  # comparison, which keeps this correct if another field is ever added.
  def ==(other)
    other.class == self.class && other.characteristic == characteristic
  end
  alias eql? ==

  def hash = [self.class, characteristic].hash

  def to_s = name
end

# A field of prime order, Z/pZ. Every field with p elements is isomorphic to
# this one, which is what makes the order alone a complete description.
#
# ("Prime field" would be the looser term: it means a field without proper
# subfields, and RationalField is one of those too.)
#
# Every coefficient is represented by its smallest non-negative residue, so
# 0 <= coefficient < p.
class PrimeOrderField < Field
  attr_reader :characteristic

  def initialize(characteristic)
    raise ArgumentError, "#{characteristic} is not prime" unless self.class.prime?(characteristic)

    super()
    @characteristic = characteristic
  end

  # Trial division is more than enough for the small primes used in class.
  def self.prime?(number)
    return false if number < 2
    return true if number < 4
    return false if (number % 2).zero?

    divisor = 3
    while divisor * divisor <= number
      return false if (number % divisor).zero?

      divisor += 2
    end
    true
  end

  def parse(text)
    Integer(text, 10)
  rescue ArgumentError, TypeError
    raise ArgumentError, "#{text.inspect} is not an integer"
  end

  def normalize(value) = value % characteristic

  # The inverse is found by trying every residue; for the small characteristics
  # used in teaching this is both fast enough and easy to follow.
  def inverse(value)
    normalized = normalize(value)
    raise ZeroDivisionError, "0 has no multiplicative inverse in #{name}" if normalized.zero?

    (1...characteristic).each do |candidate|
      return candidate if (candidate * normalized) % characteristic == 1
    end
    # Unreachable for a prime characteristic, but keeps the failure explicit.
    raise ZeroDivisionError, "#{value} has no multiplicative inverse in #{name}"
  end

  def coefficient_to_s(value) = value.to_s
  def coefficient_to_latex(value) = value.to_s
  def name = "Z/#{characteristic}Z"
  def latex_name = "\\mathbb{Z}/#{characteristic}\\mathbb{Z}"
end

# The rational numbers. Input may be given as "3", "-3", "1/2" or "0.5"; the
# coefficients stay exact, so a quotient of 1/2 is never rounded away.
class RationalField < Field
  def parse(text)
    Rational(text)
  rescue ArgumentError, TypeError, ZeroDivisionError
    raise ArgumentError, "#{text.inspect} is not a rational number"
  end

  def normalize(value) = Rational(value)
  def zero = Rational(0)

  # No multiple of 1 is ever 0 in Q, so the characteristic is 0.
  def characteristic = 0

  def inverse(value)
    raise ZeroDivisionError, "0 has no multiplicative inverse in #{name}" if value.zero?

    1 / Rational(value)
  end

  def prints_with_minus?(value) = value.negative?
  def without_sign(value) = value.abs

  def coefficient_to_s(value)
    value.denominator == 1 ? value.numerator.to_s : "#{value.numerator}/#{value.denominator}"
  end

  # In front of a variable a fraction is bracketed, so that "(1/2)x" cannot be
  # misread as "1/(2x)". On its own, "1/2" is unambiguous and reads better.
  def coefficient_factor_to_s(value)
    value.denominator == 1 ? value.numerator.to_s : "(#{coefficient_to_s(value)})"
  end

  def coefficient_to_latex(value)
    return value.numerator.to_s if value.denominator == 1

    sign = value.negative? ? "-" : ""
    "#{sign}\\frac{#{value.numerator.abs}}{#{value.denominator}}"
  end

  def name = "Q"
  def latex_name = "\\mathbb{Q}"
end

# --------------------------------------------------------------------------
# Polynomials
# --------------------------------------------------------------------------

# The ring the division actually takes place in: polynomials in one variable
# over a field, written Z/5Z[x] or Q[t].
#
# The field on its own cannot name it. It knows that it is Z/5Z, but which
# symbol is the variable is not its business - only the two together say what
# the tableau in front of the reader is a division in.
class PolynomialRing
  attr_reader :field, :variable

  def initialize(field, variable)
    @field = field
    @variable = variable
  end

  def name = "#{field.name}[#{variable}]"
  def latex_name = "#{field.latex_name}[#{variable}]"
  def to_s = name
end

# A polynomial over a given field.
#
# Coefficients are stored in ascending order of the exponent, so
# +coefficients[i]+ belongs to x^i. Trailing zeros are removed on construction,
# which makes the degree unambiguous and the zero polynomial unique.
class Polynomial
  attr_reader :coefficients, :field

  def initialize(coefficients, field)
    @field = field
    @coefficients = coefficients.map { |c| field.normalize(c) }
    @coefficients.pop while !@coefficients.empty? && field.zero?(@coefficients.last)
    @coefficients.freeze
  end

  # Reads a comma separated list of coefficients, lowest exponent first.
  def self.parse(text, field)
    parts = text.to_s.split(",").map(&:strip)
    raise ArgumentError, "no coefficients given" if parts.empty?

    new(parts.map { |part| field.parse(part) }, field)
  end

  def self.zero(field) = new([], field)

  # The monomial coefficient * x^exponent.
  def self.monomial(coefficient, exponent, field)
    new(Array.new(exponent, field.zero) << coefficient, field)
  end

  # Conventionally deg(0) is left undefined or set to minus infinity. Here the
  # zero polynomial reports -1, which is the largest value that keeps
  # "degree < divisor.degree" true for every divisor and so lets the division
  # loop end without a special case. Callers that print a degree guard with
  # zero? first.
  def degree = coefficients.length - 1
  def zero? = coefficients.empty?
  def leading_coefficient = coefficients.last

  def coefficient(exponent)
    return field.zero if exponent.negative? || exponent > degree

    coefficients[exponent]
  end

  def +(other) = combine(other) { |a, b| field.add(a, b) }
  def -(other) = combine(other) { |a, b| field.subtract(a, b) }

  def *(other)
    return self.class.zero(field) if zero? || other.zero?

    product = Array.new(degree + other.degree + 1, field.zero)
    coefficients.each_with_index do |a, i|
      other.coefficients.each_with_index do |b, j|
        product[i + j] = field.add(product[i + j], field.multiply(a, b))
      end
    end
    self.class.new(product, field)
  end

  # The coefficients have to match and they have to be read in the same field:
  # [1] over Z/5Z and [1] over Q hold numerically equal entries but are not the
  # same polynomial.
  def ==(other)
    other.is_a?(Polynomial) && coefficients == other.coefficients && field == other.field
  end
  alias eql? ==

  def hash = [coefficients, field].hash

  def to_s(variable = "x") = ShellFormatter.new(variable).polynomial(self)

  def inspect = "#<Polynomial #{self} over #{field.name}>"

  private

  def combine(other)
    length = [coefficients.length, other.coefficients.length].max
    merged = Array.new(length) { |i| yield(coefficient(i), other.coefficient(i)) }
    self.class.new(merged, field)
  end
end

# --------------------------------------------------------------------------
# The division itself
# --------------------------------------------------------------------------

# One line of the calculation: the quotient term that was found, the multiple
# of the divisor it produces, and what is left after subtracting it.
Step = Struct.new(:quotient_term, :subtrahend, :remainder)

# Divides one polynomial by another and keeps every intermediate step, so the
# calculation can be replayed on screen instead of only showing the result.
class LongDivision
  attr_reader :dividend, :divisor, :field, :steps, :quotient, :remainder

  def initialize(dividend, divisor)
    raise ArgumentError, "cannot divide by the zero polynomial" if divisor.zero?

    @dividend = dividend
    @divisor = divisor
    @field = dividend.field
    @steps = []
    divide
  end

  # True when the divisor divides the dividend without anything left over.
  def exact? = remainder.zero?

  private

  # The familiar school algorithm: as long as the remainder still reaches the
  # degree of the divisor, cancel its leading term and subtract. A dividend of
  # lower degree than the divisor simply yields no step at all, quotient 0 and
  # the dividend as remainder.
  def divide
    @remainder = dividend
    quotient_terms = []

    while !@remainder.zero? && @remainder.degree >= divisor.degree
      exponent = @remainder.degree - divisor.degree
      factor = field.multiply(@remainder.leading_coefficient,
                              field.inverse(divisor.leading_coefficient))

      term = Polynomial.monomial(factor, exponent, field)
      subtrahend = term * divisor
      next_remainder = @remainder - subtrahend

      quotient_terms << term
      @steps << Step.new(term, subtrahend, next_remainder)
      @remainder = next_remainder
    end

    @quotient = quotient_terms.reduce(Polynomial.zero(field)) { |sum, term| sum + term }
  end
end

# --------------------------------------------------------------------------
# Rendering for the terminal
# --------------------------------------------------------------------------

# Turns a division into the plain text tableau.
#
# Every exponent gets a column of its own so that equal powers line up beneath
# each other. A column consists of a three character separator (" + ", " - ",
# " -(" or blank) followed by the term itself, right aligned to a common width.
class ShellFormatter
  SEPARATOR_WIDTH = 3
  SUPERSCRIPTS = "⁰¹²³⁴⁵⁶⁷⁸⁹"

  def initialize(variable = "x")
    @variable = variable
  end

  # A single polynomial without any padding, e.g. "3x² + 4".
  def polynomial(poly)
    return "0" if poly.zero?

    @field = poly.field
    poly.degree.downto(0).filter_map { |exponent| cell(poly, exponent) }
        .each_with_index
        .map { |(separator, body), index| index.zero? ? body : "#{separator}#{body}" }
        .join
  end

  # The complete calculation, ready to be printed.
  def division(division)
    @field = division.field
    @max_degree = [division.dividend.degree, 0].max
    @divisor_degree = division.divisor.degree
    @width = body_width(division)

    lines = [header(division)]
    division.steps.each do |step|
      lines << row(step.subtrahend, prefix: " -(", close: true)
      lines << :rule
      lines << row(step.remainder, lowest: carried_down_to(step.remainder))
    end

    rule = "-" * lines.grep(String).map(&:length).max
    lines.map { |line| line == :rule ? rule : line }.join("\n")
  end

  # The closing line that lets the reader verify the result.
  def verification(division)
    parts = ["(#{polynomial(division.quotient)}) · (#{polynomial(division.divisor)})"]
    parts << "(#{polynomial(division.remainder)})" unless division.remainder.zero?
    "#{polynomial(division.dividend)} = #{parts.join(' + ')}"
  end

  private

  attr_reader :variable, :field, :max_degree, :divisor_degree, :width

  # How far down a remainder is written out. Just as when dividing by hand, only
  # the terms that have been brought down so far are shown: after a subtraction
  # you fetch exactly as many terms of the dividend as the next subtrahend is
  # wide, and the rest stays untouched above until it is needed.
  #
  # The last remainder has a degree below that of the divisor, so this yields 0
  # and the final result is written out in full.
  def carried_down_to(remainder)
    [remainder.degree - divisor_degree, 0].max
  end

  def header(division)
    dividend = row(division.dividend, prefix: "  (", close: true)
    "#{dividend} : (#{polynomial(division.divisor)}) = #{polynomial(division.quotient)}"
  end

  # Lays a polynomial out on the column grid, indented so that its leading term
  # sits underneath the matching power of the dividend.
  def row(poly, prefix: "   ", close: false, lowest: 0)
    parts = [blank_column * indent(poly), prefix]

    if poly.zero?
      parts << " " * SEPARATOR_WIDTH << "0".rjust(width)
    else
      emitted = false
      poly.degree.downto(lowest) do |exponent|
        pair = cell(poly, exponent)
        if pair.nil?
          parts << blank_column
          next
        end

        separator, body = pair
        parts << (emitted ? separator : " " * SEPARATOR_WIDTH) << body.rjust(width)
        emitted = true
      end
    end

    # Trailing blank columns are dropped first so that the closing bracket sits
    # directly behind the last term instead of floating off to the right.
    line = parts.join.rstrip
    close ? "#{line})" : line
  end

  # How many columns a polynomial has to be pushed to the right so that its
  # leading term lands in the column of its own power.
  def indent(poly) = max_degree - [poly.degree, 0].max

  # Renders one term as [separator, body], or nil if the coefficient is zero.
  # The sign of the leading term is glued to the body, later signs become the
  # separator so that "x² - 3" reads naturally.
  def cell(poly, exponent)
    coefficient = poly.coefficient(exponent)
    return nil if field.zero?(coefficient)

    negative = field.prints_with_minus?(coefficient)
    body = term_body(field.without_sign(coefficient), exponent)

    return [" " * SEPARATOR_WIDTH, negative ? "-#{body}" : body] if exponent == poly.degree

    [negative ? " - " : " + ", body]
  end

  def term_body(coefficient, exponent)
    return field.coefficient_to_s(coefficient) if exponent.zero?

    prefix = field.one?(coefficient) ? "" : field.coefficient_factor_to_s(coefficient)
    "#{prefix}#{variable}#{superscript(exponent)}"
  end

  def superscript(exponent)
    return "" if exponent == 1

    exponent.to_s.tr("0123456789", SUPERSCRIPTS)
  end

  def blank_column = " " * (SEPARATOR_WIDTH + width)

  # The widest term of any polynomial that will be printed decides the column
  # width, so nothing can overflow its column.
  def body_width(division)
    polynomials = [division.dividend, division.quotient, division.remainder]
    polynomials += division.steps.flat_map { |step| [step.subtrahend, step.remainder] }

    polynomials.flat_map { |poly| poly.degree.downto(0).filter_map { |e| cell(poly, e)&.last&.length } }
               .push(1)
               .max
  end
end

# --------------------------------------------------------------------------
# Rendering for LaTeX
# --------------------------------------------------------------------------

# Writes the same tableau as a LaTeX array. Each exponent occupies two columns,
# one for the sign and one for the term, which keeps the powers aligned and
# lets \cline underline exactly the part that is being subtracted.
class LatexFormatter
  ORIENTATIONS = %w[auto portrait landscape].freeze

  # A division wider than this many characters in the shell rendering is put on
  # a landscape page. Measured on A4 with 2cm margins: one character is worth
  # roughly 5.7pt once typeset, and the text block offers 484pt upright against
  # 731pt across, so about 85 characters still fit in portrait.
  PORTRAIT_LIMIT = 80

  def initialize(variable = "x", orientation: "auto")
    unless ORIENTATIONS.include?(orientation)
      raise ArgumentError, "orientation must be one of #{ORIENTATIONS.join(', ')}, got #{orientation}"
    end

    @variable = variable
    @orientation = orientation
  end

  def document(division)
    @field = division.field
    @max_degree = [division.dividend.degree, 0].max
    @divisor_degree = division.divisor.degree

    <<~LATEX
      \\documentclass[a4paper]{article}
      \\usepackage[#{geometry_options(division)}]{geometry}
      \\usepackage{amsmath}
      \\usepackage{amssymb}
      \\usepackage{adjustbox}
      \\pagestyle{empty}
      \\begin{document}
      % Without naming the ring the tableau is ambiguous: the same coefficients
      % mean different things over Q than over Z/pZ.
      \\begin{center}
      Long division in $#{PolynomialRing.new(field, variable).latex_name}$
      \\end{center}
      % Long polynomials can outgrow even the wider of the two page shapes.
      % "max totalsize" shrinks the tableau just enough to keep it on the paper,
      % in width and in height; one that already fits keeps its natural size.
      % The heading needs a little of the height, hence 0.9 rather than 1.
      \\begin{adjustbox}{max totalsize={\\textwidth}{0.9\\textheight},center}
      $\\begin{array}{#{'r' * column_count}}
      #{body(division).join("\n")}
      \\end{array}$
      \\end{adjustbox}
      \\end{document}
    LATEX
  end

  # How wide the tableau will be, measured on the shell rendering, which is a
  # faithful proxy: both put every power in a column of its own.
  def self.width_in_characters(division, variable)
    ShellFormatter.new(variable).division(division).lines(chomp: true).map(&:length).max
  end

  # A single polynomial in inline form, e.g. "3x^{2} + 4".
  def polynomial(poly)
    return "0" if poly.zero?

    @field = poly.field
    poly.degree.downto(0).filter_map { |exponent| cell(poly, exponent) }
        .each_with_index
        .map { |(sign, body), index| index.zero? ? body : " #{sign} #{body}" }
        .join
  end

  private

  attr_reader :variable, :field, :max_degree, :divisor_degree, :orientation

  def geometry_options(division)
    landscape?(division) ? "landscape,margin=2cm" : "margin=2cm"
  end

  def landscape?(division)
    case orientation
    when "portrait" then false
    when "landscape" then true
    else self.class.width_in_characters(division, variable) > PORTRAIT_LIMIT
    end
  end

  # One indent column, two columns per exponent, one for the closing bracket
  # and one for the ": (divisor) = quotient" that trails the first row.
  def column_count = 2 * (max_degree + 1) + 3

  def body(division)
    trailer = ": (#{polynomial(division.divisor)}) = #{polynomial(division.quotient)}"
    lines = [row(division.dividend, open: "(", trailer: trailer)]

    division.steps.each do |step|
      lines << "#{row(step.subtrahend, open: '-(')}#{cline(step.subtrahend)}"
      lines << row(step.remainder, lowest: carried_down_to(step.remainder))
    end
    lines
  end

  # See ShellFormatter#carried_down_to: only the terms brought down so far are
  # written out, which keeps both renderings identical.
  def carried_down_to(remainder)
    [remainder.degree - divisor_degree, 0].max
  end

  def row(poly, open: nil, trailer: nil, lowest: 0)
    cells = [""] * (1 + 2 * indent(poly))

    if poly.zero?
      cells.push("", "0")
    else
      emitted = false
      poly.degree.downto(lowest) do |exponent|
        pair = cell(poly, exponent)
        if pair.nil?
          cells.push("", "")
          next
        end

        sign, body = pair
        cells.push(emitted ? sign : open.to_s, body)
        emitted = true
      end
    end

    cells << ")" if open
    cells << trailer if trailer
    "#{cells.join(' & ')} \\\\"
  end

  def indent(poly) = max_degree - [poly.degree, 0].max

  # Underlines everything from the leading sign of the subtrahend to the very
  # last column of the grid, mirroring the dashed rule of the shell output.
  def cline(poly)
    "\\cline{#{2 + 2 * indent(poly)}-#{3 + 2 * max_degree}}"
  end

  def cell(poly, exponent)
    coefficient = poly.coefficient(exponent)
    return nil if field.zero?(coefficient)

    negative = field.prints_with_minus?(coefficient)
    body = term_body(field.without_sign(coefficient), exponent)
    return ["", negative ? "-#{body}" : body] if exponent == poly.degree

    [negative ? "-" : "+", body]
  end

  def term_body(coefficient, exponent)
    return field.coefficient_to_latex(coefficient) if exponent.zero?

    prefix = field.one?(coefficient) ? "" : field.coefficient_to_latex(coefficient)
    power = exponent == 1 ? "" : "^{#{exponent}}"
    "#{prefix}#{variable}#{power}"
  end
end

# --------------------------------------------------------------------------
# Command line interface
# --------------------------------------------------------------------------

# Parses the arguments, runs the division and prints whatever was asked for.
class CLI
  DEFAULT_TEX_FILE = "division.tex"
  USAGE = "Usage: ruby pd.rb [options] DIVIDEND DIVISOR [CHARACTERISTIC] [VARIABLE]"

  # Only a dash followed by a letter can start an option. A coefficient list
  # may well start with a negative number ("-6,11,-6,1"), which OptionParser
  # would otherwise reject as an unknown option.
  OPTION_PATTERN = /\A--?[a-zA-Z]/
  OPTIONS_WITH_VALUE = %w[-o --output -r --orientation].freeze

  # Shown at the end of --help. Each entry is a command and one line saying
  # what it divides by what, so the coefficient order can be read off directly.
  EXAMPLES = [
    ['ruby pd.rb "3,0,0,1,1" "4,0,3" 5 x',
     "divides x^4 + x^3 + 3 by 3x^2 + 4 in Z/5Z"],
    ['ruby pd.rb "-6,11,-6,1" "-2,1"',
     "divides x^3 - 6x^2 + 11x - 6 by x - 2 over the rational numbers"],
    ['ruby pd.rb "1,0,1" "1,1" 2 t',
     "divides t^2 + 1 by t + 1 in Z/2Z, printed with t as the variable"],
    ['ruby pd.rb "1/2,0,1" "1,1"',
     "coefficients may be fractions: divides x^2 + 1/2 by x + 1"],
    ['ruby pd.rb --verbose "3,0,0,1,1" "4,0,3" 5',
     "same as the first example, but also lists every intermediate polynomial"],
    ['ruby pd.rb --pdf "3,0,0,1,1" "4,0,3" 5',
     "same again, and typesets the tableau into division.pdf via pdflatex"],
    ['ruby pd.rb --pdf --orientation landscape "3,0,0,1,1" "4,0,3" 5',
     "forces a landscape page; by default the orientation follows the width"]
  ].freeze

  Options = Struct.new(:help, :verbose, :latex, :pdf, :output, :orientation, keyword_init: true)

  def self.run(argv, out: $stdout, err: $stderr)
    new(argv, out: out, err: err).run
  rescue ArgumentError, ZeroDivisionError => e
    err.puts "error: #{e.message}"
    1
  end

  def initialize(argv, out: $stdout, err: $stderr)
    @argv = argv.dup
    @out = out
    @err = err
    @options = Options.new(help: false, verbose: false, latex: false, pdf: false,
                           output: DEFAULT_TEX_FILE, orientation: "auto")
  end

  def run
    positional = parse_options
    if options.help
      out.puts @parser
      return 0
    end
    return usage(out, 0) if positional.empty?
    return usage(err, 1) if positional.length < 2

    dividend_text, divisor_text, characteristic_text, variable = positional
    field = Field.build(parse_characteristic(characteristic_text))

    division = LongDivision.new(
      Polynomial.parse(dividend_text, field),
      Polynomial.parse(divisor_text, field)
    )

    report(division, field, variable || "x")
    0
  end

  private

  attr_reader :argv, :out, :err, :options

  def parse_options
    @parser = OptionParser.new do |o|
      o.banner = USAGE
      o.separator ""
      o.separator "Coefficients are listed lowest exponent first, so \"3,0,0,1,1\" means x^4 + x^3 + 3."
      o.separator "CHARACTERISTIC is a prime p for Z/pZ, or 0 for the rational numbers (default 0)."
      o.separator "VARIABLE is the symbol used when printing (default x)."
      o.separator ""
      o.on("-v", "--verbose", "Print the intermediate polynomials of every step")
      o.on("-l", "--latex", "Also write the tableau as a LaTeX document")
      o.on("-o", "--output FILE", "Where to write it (default #{DEFAULT_TEX_FILE}, implies --latex)")
      o.on("-p", "--pdf", "Run pdflatex on the generated file (implies --latex)")
      o.on("-r", "--orientation NAME", LatexFormatter::ORIENTATIONS,
           "Page orientation: #{LatexFormatter::ORIENTATIONS.join(', ')} (default auto)")
      o.on("-h", "--help", "Show this message")
      o.separator ""
      o.separator "Examples:"
      EXAMPLES.each do |command, explanation|
        o.separator "  #{command}"
        o.separator "      #{explanation}"
      end
    end

    flags, positional = split_arguments
    found = {}
    @parser.parse(flags, into: found)

    options.help = found.fetch(:help, false)
    options.verbose = found.fetch(:verbose, false)
    options.pdf = found.fetch(:pdf, false)
    options.output = found[:output] if found[:output]
    options.orientation = found[:orientation] if found[:orientation]
    options.latex = found.fetch(:latex, false) || options.pdf || found.key?(:output)
    positional
  rescue OptionParser::ParseError => e
    raise ArgumentError, e.message
  end

  # Splits the command line into options and operands by hand, because a
  # polynomial may legitimately start with a minus sign. Everything after a
  # literal "--" is an operand, as usual.
  def split_arguments
    flags = []
    operands = []
    rest = argv.dup

    until rest.empty?
      token = rest.shift
      if token == "--"
        return [flags, operands + rest]
      elsif token.match?(OPTION_PATTERN)
        flags << token
        flags << rest.shift if OPTIONS_WITH_VALUE.include?(token) && !rest.empty?
      else
        operands << token
      end
    end

    [flags, operands]
  end

  def parse_characteristic(text)
    return 0 if text.nil?

    Integer(text, 10)
  rescue ArgumentError, TypeError
    raise ArgumentError, "characteristic must be an integer, got #{text.inspect}"
  end

  def report(division, field, variable)
    shell = ShellFormatter.new(variable)

    print_steps(division, shell) if options.verbose

    out.puts
    out.puts "Long division in #{PolynomialRing.new(field, variable).name}:"
    out.puts
    out.puts shell.division(division)
    out.puts
    out.puts "Check: #{shell.verification(division)}"

    write_latex(division, variable) if options.latex
  end

  def print_steps(division, shell)
    division.steps.each_with_index do |step, index|
      out.puts "step #{index + 1}"
      out.puts "  quotient term: #{shell.polynomial(step.quotient_term)}"
      out.puts "  subtrahend:    #{shell.polynomial(step.subtrahend)}"
      out.puts "  remainder:     #{shell.polynomial(step.remainder)}"
    end
  end

  def write_latex(division, variable)
    formatter = LatexFormatter.new(variable, orientation: options.orientation)
    File.write(options.output, formatter.document(division))
    out.puts "LaTeX written to #{options.output}"
    run_pdflatex if options.pdf
  end

  def run_pdflatex
    if system("pdflatex", "-interaction=nonstopmode", options.output, out: File::NULL)
      out.puts "PDF written to #{options.output.sub(/\.tex\z/, '')}.pdf"
    else
      err.puts "warning: pdflatex failed or is not installed; #{options.output} was kept"
    end
  end

  def usage(io, status)
    io.puts USAGE
    io.puts "Example: #{EXAMPLES.first.first}"
    io.puts "Run 'ruby pd.rb --help' for all options and more examples."
    status
  end
end

exit CLI.run(ARGV) if $PROGRAM_NAME == __FILE__
