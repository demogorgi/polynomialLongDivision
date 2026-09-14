# polynomialLongDivision

Polynomial long division, worked out step by step, with shell and LaTeX output.
By Uwe Gotzes.

Coefficients may live in the field **Z/pZ** for a prime p, or in the **rational numbers**.
Both the shell output and the PDF state the polynomial ring the division runs
in — `Z/5Z[x]`, `Q[t]` — because the same coefficients mean different things
over different rings.

The calculation is laid out in the Central European notation taught in
German-speaking classrooms — dividend and divisor on one line, joined by `:`,
the quotient after the `=`, and the subtraction steps underneath:

```
(dividend) : (divisor) = quotient
```

Terms of the dividend are brought down one group at a time, just as when
dividing by hand: after each subtraction only as many terms are fetched as the
next subtrahend is wide, and the final remainder is written out in full.

(English-language textbooks use the long division bracket with the quotient
written above the dividend instead. Only the layout differs, not the method.)

## Usage

```
ruby pd.rb [options] DIVIDEND DIVISOR [CHARACTERISTIC] [VARIABLE]
```

| Argument | Meaning |
| --- | --- |
| `DIVIDEND`, `DIVISOR` | Comma separated coefficients, **lowest exponent first**. `"3,0,0,1,1"` is `x⁴ + x³ + 3`. |
| `CHARACTERISTIC` | A prime `p` for Z/pZ, or `0` for the rational numbers. Default `0`. |
| `VARIABLE` | The symbol used when printing. Default `x`. |

| Option | Effect |
| --- | --- |
| `-v`, `--verbose` | Also print the intermediate polynomials of every step. |
| `-l`, `--latex` | Write the tableau as a LaTeX document. |
| `-o`, `--output FILE` | Where to write it (default `division.tex`, implies `--latex`). |
| `-p`, `--pdf` | Run `pdflatex` on the generated file (implies `--latex`). |
| `-r`, `--orientation NAME` | `auto`, `portrait` or `landscape`. Default `auto`. |
| `-h`, `--help` | Show all options. |

Nothing is written to disk unless `--latex`, `--output` or `--pdf` is given.

### Page layout

With `--orientation auto`, a short division is typeset upright and a wide one
on a landscape page. Should the tableau still be too large for the paper — very
long polynomials produce very wide tableaus — it is scaled down just enough to
fit, in width and in height. It therefore always stays on a single page and
never runs off the edge; only the type gets smaller.

## Examples

### In a field of prime order

```
ruby pd.rb "3,0,0,1,1" "4,0,3" 5 x
```

```
Long division in Z/5Z[x]:

  (    x⁴ +  x³             +   3) : (3x² + 4) = 2x² + 2x + 4
 -(    x⁴       + 3x²)
-------------------------------------------------------------
             x³ + 2x²
       -(    x³       +  3x)
-------------------------------------------------------------
                  2x² +  2x +   3
             -(   2x²       +   1)
-------------------------------------------------------------
                         2x +   2

Check: x⁴ + x³ + 3 = (2x² + 2x + 4) · (3x² + 4) + (2x + 2)
```

### Over the rational numbers

```
ruby pd.rb "-6,11,-6,1" "-2,1"
```

```
Long division in Q[x]:

  (     x³ -  6x² +  11x -    6) : (x - 2) = x² - 4x + 3
 -(     x³ -  2x²)
--------------------------------------------------------
             -4x² +  11x
        -(   -4x² +   8x)
--------------------------------------------------------
                      3x -    6
               -(     3x -    6)
--------------------------------------------------------
                              0

Check: x³ - 6x² + 11x - 6 = (x² - 4x + 3) · (x - 2)
```

Rational coefficients stay exact. They may be entered as `1/2` or as `0.5`. In
front of a variable they are bracketed — `(1/2)x`, so it cannot be misread as
`1/(2x)` — while a constant term stays plain: `x² + 1/2`.

`ruby pd.rb --help` lists further examples.

### As a PDF

```
ruby pd.rb --pdf "3,0,0,1,1" "4,0,3" 5 x
```

## Requirements

Ruby 3.0 or newer, no gems.

`pdflatex` is only needed for `--pdf`. The generated document uses `geometry`,
`amsmath`, `amssymb` and `adjustbox`, all part of a standard TeX Live or MiKTeX
install.

## Tests

```
ruby test/test_pd.rb
```

## How it works

`pd.rb` is a single self-contained script:

| Part | Responsibility |
| --- | --- |
| `Field`, `PrimeOrderField`, `RationalField` | The coefficient field: parsing, arithmetic, inverses, rendering. |
| `PolynomialRing` | Field plus variable — the ring the division runs in, `Z/5Z[x]`. |
| `Polynomial` | Coefficients in ascending order of the exponent, plus `+`, `-`, `*`. |
| `LongDivision` | The school algorithm, keeping every intermediate step. |
| `ShellFormatter`, `LatexFormatter` | The two renderings of the same tableau. |
| `CLI` | Argument handling and output. |
