# frozen_string_literal: true

require "minitest/autorun"
require "stringio"
require "tmpdir"
require_relative "../pd"

class FieldTest < Minitest::Test
  def test_build_selects_the_rational_numbers_for_characteristic_zero
    assert_instance_of RationalField, Field.build(0)
  end

  def test_build_still_accepts_one_as_an_alias_for_the_rational_numbers
    assert_instance_of RationalField, Field.build(1)
  end

  # 1 is only a legacy spelling of "not a finite field". There is no field of
  # characteristic 1, so the field it builds must not claim to have one.
  def test_the_legacy_alias_does_not_become_a_characteristic
    assert_equal 0, Field.build(1).characteristic
  end

  def test_fields_report_their_characteristic
    assert_equal 0, Field.build(0).characteristic
    assert_equal 5, Field.build(5).characteristic
  end

  def test_a_composite_order_is_refused_by_the_field_itself
    error = assert_raises(ArgumentError) { PrimeOrderField.new(4) }
    assert_match(/not prime/, error.message)
  end

  def test_build_rejects_a_composite_characteristic
    error = assert_raises(ArgumentError) { Field.build(4) }
    assert_match(/prime/, error.message)
  end

  def test_build_rejects_a_negative_characteristic
    assert_raises(ArgumentError) { Field.build(-5) }
  end

  def test_prime_field_normalizes_into_the_smallest_non_negative_residue
    field = Field.build(5)
    assert_equal 3, field.normalize(-2)
    assert_equal 1, field.normalize(11)
  end

  def test_prime_field_inverses
    field = Field.build(7)
    (1..6).each do |value|
      assert_equal 1, (value * field.inverse(value)) % 7, "#{value} has a wrong inverse"
    end
  end

  def test_prime_field_has_no_inverse_of_zero
    assert_raises(ZeroDivisionError) { Field.build(5).inverse(0) }
  end

  def test_rational_field_parses_fractions_and_decimals
    field = Field.build(0)
    assert_equal Rational(1, 2), field.parse("1/2")
    assert_equal Rational(1, 2), field.parse("0.5")
    assert_equal Rational(-3), field.parse("-3")
  end

  def test_rational_field_rejects_nonsense
    assert_raises(ArgumentError) { Field.build(0).parse("banana") }
  end

  def test_fields_with_the_same_characteristic_are_equal
    assert_equal Field.build(5), Field.build(5)
    assert_equal Field.build(0), Field.build(0)
    assert_equal Field.build(0).hash, Field.build(1).hash
  end

  def test_different_fields_are_not_equal
    refute_equal Field.build(5), Field.build(7)
    refute_equal Field.build(5), Field.build(0)
  end

  def test_a_field_is_not_equal_to_something_that_is_not_a_field
    refute_equal Field.build(5), 5
    refute_equal Field.build(5), "Z/5Z"
  end

  def test_fields_can_be_used_as_hash_keys
    counts = Hash.new(0)
    counts[Field.build(5)] += 1
    counts[Field.build(5)] += 1
    counts[Field.build(7)] += 1

    assert_equal({ Field.build(5) => 2, Field.build(7) => 1 }, counts)
  end

  def test_fields_name_themselves_but_not_a_variable
    assert_equal "Z/5Z", Field.build(5).name
    assert_equal "Q", Field.build(0).name
    assert_equal "\\mathbb{Z}/5\\mathbb{Z}", Field.build(5).latex_name
    assert_equal "\\mathbb{Q}", Field.build(0).latex_name
  end
end

# The tableau alone is ambiguous, so both outputs name the ring the division
# runs in - which also says which symbol is the variable.
class PolynomialRingTest < Minitest::Test
  def test_the_ring_combines_the_field_with_the_variable
    assert_equal "Z/5Z[x]", PolynomialRing.new(Field.build(5), "x").name
    assert_equal "Q[t]", PolynomialRing.new(Field.build(0), "t").name
  end

  def test_the_ring_has_a_latex_spelling
    assert_equal "\\mathbb{Z}/5\\mathbb{Z}[x]", PolynomialRing.new(Field.build(5), "x").latex_name
    assert_equal "\\mathbb{Q}[t]", PolynomialRing.new(Field.build(0), "t").latex_name
  end
end

class PolynomialTest < Minitest::Test
  def setup
    @f5 = Field.build(5)
    @q = Field.build(0)
  end

  def test_parse_reads_the_lowest_exponent_first
    poly = Polynomial.parse("3,0,0,1,1", @f5)
    assert_equal 4, poly.degree
    assert_equal 3, poly.coefficient(0)
    assert_equal 1, poly.coefficient(4)
  end

  def test_trailing_zeros_do_not_raise_the_degree
    assert_equal 1, Polynomial.parse("1,1,0,0", @f5).degree
  end

  def test_coefficients_that_vanish_modulo_p_lower_the_degree
    # 5 == 0 in Z/5Z, so "4,0,5" is the constant 4, not a quadratic.
    assert_equal 0, Polynomial.parse("4,0,5", @f5).degree
  end

  def test_the_zero_polynomial_has_degree_minus_one
    poly = Polynomial.parse("0,0,0", @f5)
    assert poly.zero?
    assert_equal(-1, poly.degree)
  end

  def test_coefficient_outside_the_polynomial_is_zero
    poly = Polynomial.parse("1,1", @f5)
    assert_equal 0, poly.coefficient(7)
    assert_equal 0, poly.coefficient(-1)
  end

  def test_addition_wraps_around_in_a_prime_field
    sum = Polynomial.parse("3,4", @f5) + Polynomial.parse("4,3", @f5)
    assert_equal Polynomial.parse("2,2", @f5), sum
  end

  def test_subtraction_can_cancel_the_leading_term
    difference = Polynomial.parse("1,1,1", @q) - Polynomial.parse("0,0,1", @q)
    assert_equal 1, difference.degree
  end

  def test_multiplication
    # (x + 1)(x + 2) == x^2 + 3x + 2
    product = Polynomial.parse("1,1", @q) * Polynomial.parse("2,1", @q)
    assert_equal Polynomial.parse("2,3,1", @q), product
  end

  def test_multiplication_by_zero
    assert Polynomial.parse("1,2,3", @q).*(Polynomial.zero(@q)).zero?
  end

  def test_monomial
    poly = Polynomial.monomial(3, 2, @q)
    assert_equal Polynomial.parse("0,0,3", @q), poly
  end

  # Ruby considers 1 and Rational(1) equal, so the coefficients alone cannot
  # tell these two apart - only the field they are read in does.
  def test_polynomials_over_different_fields_are_not_equal
    refute_equal Polynomial.parse("1,1", @f5), Polynomial.parse("1,1", @q)
  end

  def test_polynomials_can_be_used_as_hash_keys
    seen = { Polynomial.parse("1,1", @f5) => :mod5 }
    assert_equal :mod5, seen[Polynomial.parse("1,1", @f5)]
    assert_nil seen[Polynomial.parse("1,1", @q)]
  end
end

class LongDivisionTest < Minitest::Test
  def setup
    @f5 = Field.build(5)
    @q = Field.build(0)
  end

  # (x^4 + x^3 + 3) : (3x^2 + 4) in Z/5Z, the example from the README.
  def test_readme_example
    division = divide("3,0,0,1,1", "4,0,3", @f5)
    assert_equal Polynomial.parse("4,2,2", @f5), division.quotient
    assert_equal Polynomial.parse("2,2", @f5), division.remainder
    assert_equal 3, division.steps.length
  end

  def test_exact_division_leaves_no_remainder
    # (x^3 - 6x^2 + 11x - 6) : (x - 2) == x^2 - 4x + 3
    division = divide("-6,11,-6,1", "-2,1", @q)
    assert division.exact?
    assert_equal Polynomial.parse("3,-4,1", @q), division.quotient
  end

  # The bug this guards against: a quotient of 1/2 used to be dropped from the
  # output because its rendered form happened to start with the digit "0".
  def test_fractional_quotient_survives
    division = divide("0,0,1", "0,2", @q)
    assert_equal Polynomial.parse("0,1/2", @q), division.quotient
    assert_includes ShellFormatter.new("x").polynomial(division.quotient), "1/2"
  end

  # The same bug in its worst shape. Of the quotient (1/2)x - 1/2 only the
  # positive term used to be swallowed - "-1/2" does not begin with a "0" - so
  # the old output read
  #
  #   x^2 - 1 = (-0.5) * (2x + 2)
  #
  # which is false, yet looks like a finished answer rather than a visibly
  # broken one. That is the dangerous kind of wrong for a teaching tool.
  def test_a_partly_dropped_quotient_is_reported_in_full
    division = divide("-1,0,1", "2,2", @q)

    assert_equal Polynomial.parse("-1/2,1/2", @q), division.quotient
    assert division.exact?
    assert_equal "(1/2)x - 1/2", ShellFormatter.new("x").polynomial(division.quotient)
  end

  def test_dividend_of_lower_degree_yields_quotient_zero
    division = divide("1,1", "0,0,1", @f5)
    assert division.quotient.zero?
    assert_equal Polynomial.parse("1,1", @f5), division.remainder
    assert_empty division.steps
  end

  def test_dividing_by_the_zero_polynomial_is_refused
    assert_raises(ArgumentError) { divide("1,1", "0,0", @f5) }
  end

  def test_dividing_by_a_divisor_that_vanishes_modulo_p_is_refused
    # "0,5" is 5x, and 5 == 0 in Z/5Z, so the divisor is the zero polynomial.
    assert_raises(ArgumentError) { divide("1,1,1", "0,5", @f5) }
  end

  def test_every_step_lowers_the_degree
    division = divide("3,0,0,1,1", "4,0,3", @f5)
    degrees = division.steps.map { |step| step.remainder.degree }
    assert_equal degrees.sort.reverse, degrees
    refute_equal degrees.first, division.dividend.degree
  end

  # quotient * divisor + remainder == dividend must hold for every input.
  def test_division_identity_holds
    cases = [
      ["3,0,0,1,1", "4,0,3", @f5],
      ["1,2,3,4,5,6", "1,1", @f5],
      ["-6,11,-6,1", "-2,1", @q],
      ["1,0,0,0,1", "1,1", @q],
      ["0,0,1", "0,2", @q],
      ["1,1", "0,0,1", @f5]
    ]

    cases.each do |dividend_text, divisor_text, field|
      division = divide(dividend_text, divisor_text, field)
      reconstructed = division.quotient * division.divisor + division.remainder
      assert_equal division.dividend, reconstructed,
                   "#{dividend_text} : #{divisor_text} over #{field.name}"
    end
  end

  def test_remainder_degree_stays_below_the_divisor_degree
    division = divide("1,2,3,4,5,6", "1,1,1", @f5)
    assert_operator division.remainder.degree, :<, division.divisor.degree
  end

  private

  def divide(dividend, divisor, field)
    LongDivision.new(Polynomial.parse(dividend, field), Polynomial.parse(divisor, field))
  end
end

class ShellFormatterTest < Minitest::Test
  def setup
    @f5 = Field.build(5)
    @q = Field.build(0)
    @formatter = ShellFormatter.new("x")
  end

  def test_exponents_are_printed_as_superscripts
    assert_equal "x⁴ + x³ + 3", @formatter.polynomial(Polynomial.parse("3,0,0,1,1", @f5))
  end

  def test_two_digit_exponents
    poly = Polynomial.parse(([0] * 12 << 1).join(","), @f5)
    assert_equal "x¹²", @formatter.polynomial(poly)
  end

  def test_a_leading_coefficient_of_one_is_omitted
    assert_equal "x² + 2", @formatter.polynomial(Polynomial.parse("2,0,1", @f5))
  end

  def test_the_exponent_one_is_omitted
    assert_equal "3x", @formatter.polynomial(Polynomial.parse("0,3", @f5))
  end

  def test_negative_coefficients_become_a_minus_sign
    assert_equal "x² - 4x + 3", @formatter.polynomial(Polynomial.parse("3,-4,1", @q))
  end

  def test_a_fraction_in_front_of_a_variable_is_bracketed
    assert_equal "(1/2)x", @formatter.polynomial(Polynomial.parse("0,1/2", @q))
  end

  def test_a_constant_fraction_needs_no_brackets
    assert_equal "x² + 1/2", @formatter.polynomial(Polynomial.parse("1/2,0,1", @q))
  end

  def test_the_verification_line_does_not_double_its_brackets
    division = LongDivision.new(Polynomial.parse("1/2,0,1", @q), Polynomial.parse("1,1", @q))
    refute_includes @formatter.verification(division), "(("
  end

  def test_the_zero_polynomial_prints_as_zero
    assert_equal "0", @formatter.polynomial(Polynomial.zero(@q))
  end

  def test_a_custom_variable_is_used
    assert_equal "t²", ShellFormatter.new("t").polynomial(Polynomial.parse("0,0,1", @q))
  end

  def test_equal_powers_line_up_in_the_same_column
    division = LongDivision.new(Polynomial.parse("3,0,0,1,1", @f5), Polynomial.parse("4,0,3", @f5))
    lines = @formatter.division(division).lines(chomp: true)

    dividend_line = lines.first
    subtrahend_line = lines[1]
    # Both rows start with x^4, which must sit at the same offset.
    assert_equal dividend_line.index("x⁴"), subtrahend_line.index("x⁴")
  end

  # Only the terms brought down so far are written out, as one does by hand:
  # after subtracting x^3 - 2x^2 the line reads "-4x^2 + 11x", and the "- 6" is
  # only fetched in the next step.
  def test_a_remainder_shows_only_the_terms_brought_down_so_far
    division = LongDivision.new(Polynomial.parse("-6,11,-6,1", @q), Polynomial.parse("-2,1", @q))
    remainder_line = @formatter.division(division).lines(chomp: true)[3]

    assert_includes remainder_line, "-4x²"
    assert_includes remainder_line, "11x"
    refute_includes remainder_line, "6", "the constant term was fetched too early"
  end

  def test_a_gap_in_the_divisor_brings_down_the_matching_number_of_terms
    # (x^4 + x^3 + 3) : (3x^2 + 4) in Z/5Z leaves "x^3 + 2x^2"; the "+ 3" waits.
    division = LongDivision.new(Polynomial.parse("3,0,0,1,1", @f5), Polynomial.parse("4,0,3", @f5))
    remainder_line = @formatter.division(division).lines(chomp: true)[3]

    assert_includes remainder_line, "x³"
    assert_includes remainder_line, "2x²"
    refute_includes remainder_line, "3", "the constant term was fetched too early"
  end

  def test_the_last_remainder_is_written_out_in_full
    division = LongDivision.new(Polynomial.parse("3,0,0,1,1", @f5), Polynomial.parse("4,0,3", @f5))
    assert_includes @formatter.division(division).lines(chomp: true).last, "2x +   2"
  end

  def test_no_line_carries_trailing_whitespace
    division = LongDivision.new(Polynomial.parse("3,0,0,1,1", @f5), Polynomial.parse("4,0,3", @f5))
    @formatter.division(division).lines(chomp: true).each do |line|
      assert_equal line.rstrip, line, "trailing whitespace in #{line.inspect}"
    end
  end

  def test_verification_omits_a_zero_remainder
    division = LongDivision.new(Polynomial.parse("2,3,1", @q), Polynomial.parse("1,1", @q))
    refute_includes @formatter.verification(division), "+ (0)"
  end
end

class LatexFormatterTest < Minitest::Test
  def setup
    @f5 = Field.build(5)
    @division = LongDivision.new(Polynomial.parse("3,0,0,1,1", @f5), Polynomial.parse("4,0,3", @f5))
    @document = LatexFormatter.new("x").document(@division)
  end

  def test_document_is_complete
    assert_includes @document, "\\begin{document}"
    assert_includes @document, "\\end{document}"
    assert_includes @document, "\\begin{array}"
  end

  def test_every_row_fits_into_the_declared_columns
    columns = @document[/\\begin\{array\}\{(r+)\}/, 1].length
    rows = @document.lines.select { |line| line.include?("&") }

    rows.each do |row|
      cells = row.sub(/\\\\.*$/, "").count("&") + 1
      assert_operator cells, :<=, columns, "row needs #{cells} of #{columns} columns: #{row}"
    end
  end

  def test_each_subtraction_is_underlined
    assert_equal @division.steps.length, @document.scan("\\cline").length
  end

  def test_exponents_use_latex_superscripts
    assert_includes @document, "x^{4}"
    refute_includes @document, "⁴"
  end

  def test_fractions_are_typeset_as_fractions
    division = LongDivision.new(Polynomial.parse("0,0,1", Field.build(0)),
                                Polynomial.parse("0,2", Field.build(0)))
    assert_includes LatexFormatter.new("x").document(division), "\\frac{1}{2}"
  end

  # The printed sheet has to say what it is a division in; the same digits mean
  # different things over Q than over Z/pZ.
  def test_the_document_names_the_ring
    assert_includes @document, "Long division in $\\mathbb{Z}/5\\mathbb{Z}[x]$"
    assert_includes @document, "\\usepackage{amssymb}"
  end

  def test_the_heading_follows_the_chosen_variable
    document = LatexFormatter.new("t").document(
      LongDivision.new(Polynomial.parse("1,0,1", @f5), Polynomial.parse("1,1", @f5))
    )
    assert_includes document, "\\mathbb{Z}/5\\mathbb{Z}[t]"
  end

  # However long the polynomials get, the tableau is kept on the page.
  def test_the_tableau_is_capped_to_the_page_in_both_directions
    assert_includes @document, "max totalsize={\\textwidth}{0.9\\textheight}"
  end

  def test_a_short_division_stays_upright
    refute_includes LatexFormatter.new("x").document(short_division), "landscape,margin"
  end

  def test_a_wide_division_switches_to_landscape
    assert_includes LatexFormatter.new("x").document(wide_division), "landscape,margin"
  end

  def test_the_orientation_can_be_forced
    upright = LatexFormatter.new("x", orientation: "portrait").document(wide_division)
    across = LatexFormatter.new("x", orientation: "landscape").document(short_division)

    refute_includes upright, "landscape,margin"
    assert_includes across, "landscape,margin"
  end

  def test_an_unknown_orientation_is_refused
    error = assert_raises(ArgumentError) { LatexFormatter.new("x", orientation: "sideways") }
    assert_match(/orientation/, error.message)
  end

  # The character width of the shell rendering decides the orientation, so it
  # has to agree with what the shell actually prints.
  def test_the_width_proxy_matches_the_shell_rendering
    expected = ShellFormatter.new("x").division(@division).lines(chomp: true).map(&:length).max
    assert_equal expected, LatexFormatter.width_in_characters(@division, "x")
  end

  def test_the_orientation_threshold_separates_the_two_cases
    assert_operator LatexFormatter.width_in_characters(short_division, "x"),
                    :<=, LatexFormatter::PORTRAIT_LIMIT
    assert_operator LatexFormatter.width_in_characters(wide_division, "x"),
                    :>, LatexFormatter::PORTRAIT_LIMIT
  end

  private

  def short_division
    LongDivision.new(Polynomial.parse("2,3,1", @f5), Polynomial.parse("1,1", @f5))
  end

  def wide_division
    LongDivision.new(Polynomial.parse("1,2,3,4,5,6,4,3,2,1,6,5,4,3,2,1", @f5),
                     Polynomial.parse("1,2,3,4", @f5))
  end
end

class CLITest < Minitest::Test
  def test_readme_example_succeeds
    status, out, = run_cli(["3,0,0,1,1", "4,0,3", "5", "x"])
    assert_equal 0, status
    assert_includes out, "Long division in Z/5Z[x]:"
    assert_includes out, "Check:"
  end

  def test_without_arguments_it_prints_usage_and_succeeds
    status, out, err = run_cli([])
    assert_equal 0, status
    assert_includes out, "Usage:"
    assert_empty err
  end

  def test_a_single_argument_is_a_usage_error
    status, _, err = run_cli(["1,1"])
    assert_equal 1, status
    assert_includes err, "Usage:"
  end

  def test_a_composite_characteristic_is_reported_without_a_backtrace
    status, _, err = run_cli(["3,0,0,1,1", "4,0,3", "4", "x"])
    assert_equal 1, status
    assert_includes err, "error:"
    assert_includes err, "prime"
  end

  def test_a_non_numeric_characteristic_is_reported
    status, _, err = run_cli(["1,1", "1,1", "banana"])
    assert_equal 1, status
    assert_includes err, "characteristic"
  end

  def test_a_non_numeric_coefficient_is_reported
    status, _, err = run_cli(["1,banana", "1,1", "5"])
    assert_equal 1, status
    assert_includes err, "error:"
  end

  # A dividend may start with a negative coefficient; that is not an option.
  def test_a_negative_leading_coefficient_is_not_mistaken_for_an_option
    status, out, = run_cli(["-6,11,-6,1", "-2,1", "0", "x"])
    assert_equal 0, status
    assert_includes out, "Long division in Q[x]:"
  end

  def test_the_characteristic_defaults_to_the_rational_numbers
    status, out, = run_cli(["2,3,1", "1,1"])
    assert_equal 0, status
    assert_includes out, "Long division in Q[x]:"
  end

  def test_the_variable_defaults_to_x
    _, out, = run_cli(["2,3,1", "1,1"])
    assert_includes out, "x"
  end

  def test_a_custom_variable_is_used
    _, out, = run_cli(["2,3,1", "1,1", "0", "t"])
    assert_includes out, "t"
    refute_includes out, "x"
  end

  def test_verbose_shows_the_intermediate_steps
    _, quiet, = run_cli(["3,0,0,1,1", "4,0,3", "5"])
    _, loud, = run_cli(["-v", "3,0,0,1,1", "4,0,3", "5"])
    refute_includes quiet, "quotient term:"
    assert_includes loud, "quotient term:"
  end

  def test_nothing_is_written_to_disk_unless_asked
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) { run_cli(["3,0,0,1,1", "4,0,3", "5"]) }
      assert_empty Dir.children(dir)
    end
  end

  def test_latex_is_written_only_on_request
    Dir.mktmpdir do |dir|
      target = File.join(dir, "out.tex")
      status, out, = run_cli(["-o", target, "3,0,0,1,1", "4,0,3", "5"])
      assert_equal 0, status
      assert_path_exists target
      assert_includes out, "LaTeX written to"
      assert_includes File.read(target), "\\begin{array}"
    end
  end

  def test_the_orientation_option_reaches_the_document
    Dir.mktmpdir do |dir|
      target = File.join(dir, "out.tex")
      status, = run_cli(["-r", "landscape", "-o", target, "2,3,1", "1,1"])
      assert_equal 0, status
      assert_includes File.read(target), "landscape,margin"
    end
  end

  def test_an_unknown_orientation_is_reported_without_a_backtrace
    status, _, err = run_cli(["--orientation", "sideways", "2,3,1", "1,1"])
    assert_equal 1, status
    assert_includes err, "error:"
  end

  def test_an_unknown_option_is_reported
    status, _, err = run_cli(["--nonsense", "1,1", "1,1"])
    assert_equal 1, status
    assert_includes err, "error:"
  end

  def test_help_lists_the_examples
    _, out, = run_cli(["--help"])
    assert_includes out, "Examples:"
    CLI::EXAMPLES.each do |command, explanation|
      assert_includes out, command
      assert_includes out, explanation
    end
  end

  # Every command advertised in --help has to work. The --pdf example is run
  # without that flag, since pdflatex need not be installed here.
  def test_the_advertised_examples_all_run
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        CLI::EXAMPLES.each do |command, _|
          argv = command.split(/\s+(?=(?:[^"]*"[^"]*")*[^"]*$)/)[2..]
                        .map { |token| token.delete('"') } - ["--pdf"]
          status, out, err = run_cli(argv)
          assert_equal 0, status, "#{command} failed: #{err}"
          assert_includes out, "Check:", "#{command} produced no result"
        end
      end
    end
  end

  private

  def run_cli(argv)
    out = StringIO.new
    err = StringIO.new
    status = CLI.run(argv, out: out, err: err)
    [status, out.string, err.string]
  end
end

# Two complete calculations, pinned down character for character.
#
# The tests above check the pieces - a term here, a column offset there - but
# none of them would notice if the assembled tableau drifted. These two do, and
# between them they cover the cases that are easy to get wrong: a divisor whose
# leading coefficient needs inverting, a remainder that collapses to a single
# term, exponents of two digits inside the grid, and a division that comes out
# exact.
#
# Both results were verified by hand before being recorded here.
class RenderedTableauTest < Minitest::Test
  # 3 is not invertible by inspection: 3 * 2 == 6 == 1 in Z/5Z, so the first
  # quotient term is 2x^3 / 3x == 4x^2. After the first subtraction only "x^2"
  # is left standing, and the next subtrahend reaches into a column that the
  # line above leaves empty.
  EXPECTED_Z5 = <<~OUTPUT

    Long division in Z/5Z[x]:

      (   2x³ + 4x²       +   1) : (3x + 2) = 4x² + 2x + 2
     -(   2x³ + 3x²)
    ------------------------------------------------------
                 x²
           -(    x² +  4x)
    ------------------------------------------------------
                        x +   1
                 -(     x +   4)
    ------------------------------------------------------
                              2

    Check: 2x³ + 4x² + 1 = (4x² + 2x + 2) · (3x + 2) + (2)
  OUTPUT

  # Division in GF(2)[x], as it turns up in coding theory. Every coefficient is
  # 1, so no term ever prints its coefficient; the exponents run to two digits
  # and still have to line up across fourteen columns; and the division is
  # exact, so the last remainder is the zero polynomial.
  EXPECTED_GF2 = <<~OUTPUT

    Long division in Z/2Z[x]:

      (   x¹³ + x¹² + x¹¹ + x¹⁰ +  x⁹ +  x⁸       +  x⁶ +  x⁵ +  x⁴ +  x³ +  x² +   x) : (x⁷ + x⁶ + x³ + x) = x⁶ + x⁴ + x + 1
     -(   x¹³ + x¹²             +  x⁹       +  x⁷)
    -------------------------------------------------------------------------------------------------------------------------
                      x¹¹ + x¹⁰       +  x⁸ +  x⁷ +  x⁶ +  x⁵ +  x⁴
                 -(   x¹¹ + x¹⁰             +  x⁷       +  x⁵)
    -------------------------------------------------------------------------------------------------------------------------
                                         x⁸       +  x⁶       +  x⁴ +  x³ +  x² +   x
                                   -(    x⁸ +  x⁷             +  x⁴       +  x²)
    -------------------------------------------------------------------------------------------------------------------------
                                               x⁷ +  x⁶             +  x³       +   x
                                         -(    x⁷ +  x⁶             +  x³       +   x)
    -------------------------------------------------------------------------------------------------------------------------
                                                                                          0

    Check: x¹³ + x¹² + x¹¹ + x¹⁰ + x⁹ + x⁸ + x⁶ + x⁵ + x⁴ + x³ + x² + x = (x⁶ + x⁴ + x + 1) · (x⁷ + x⁶ + x³ + x)
  OUTPUT

  # Over Q, where the terms carry signs and fractions. This is the calculation
  # that the version of 2023-12-15 got visibly wrong: of the quotient it
  # printed only "-0.5", because "(1/2)x" rendered as "0.5x" back then and
  # every term whose text began with a "0" was taken for a zero term. The
  # result looked finished and was false.
  EXPECTED_Q = <<~OUTPUT

    Long division in Q[x]:

      (       x²          -      1) : (2x + 2) = (1/2)x - 1/2
     -(       x² +      x)
    ---------------------------------------------------------
                       -x -      1
              -(       -x -      1)
    ---------------------------------------------------------
                                 0

    Check: x² - 1 = ((1/2)x - 1/2) · (2x + 2)
  OUTPUT

  def test_a_divisor_with_an_invertible_leading_coefficient
    assert_equal EXPECTED_Z5, render("1,0,4,2", "2,3", "5")
  end

  def test_fractions_and_signs_over_the_rational_numbers
    assert_equal EXPECTED_Q, render("-1,0,1", "2,2", "0")
  end

  def test_an_exact_division_in_gf2_with_two_digit_exponents
    assert_equal EXPECTED_GF2, render("0,1,1,1,1,1,1,0,1,1,1,1,1,1", "0,1,0,1,0,0,1,1", "2")
  end

  # Guards the two above: if the formatter ever left padding at the end of a
  # line, the heredocs would silently stop matching for a reason that is hard
  # to see in a diff.
  def test_neither_tableau_carries_trailing_whitespace
    [EXPECTED_Z5, EXPECTED_Q, EXPECTED_GF2].each do |expected|
      expected.lines(chomp: true).each do |line|
        assert_equal line.rstrip, line, "trailing whitespace in #{line.inspect}"
      end
    end
  end

  private

  def render(*argv)
    out = StringIO.new
    err = StringIO.new
    status = CLI.run(argv, out: out, err: err)

    assert_equal 0, status, err.string
    out.string
  end
end
