# polynomialLongDivision
Polynomial long divison in finite fields with shell and Latex output by Uwe Gotzes 

Example:

Arguments are dividend, divisor, characteristic of the finite field, variable symbol
```
>ruby pd.rb "3,0,0,1,1" "4,0,3" 5 x
```
yields (among other things):
```
  (   x⁴ + x³             + 3  ) : (   3x²       + 4  ) =    2x² + 2x  + 4
- (   x⁴      + 3x² )
-------------------------------------------------------------
           x³ + 2x²
      - (  x³       + 3x )
-------------------------------------------------------------
                2x² + 2x  + 3
            - ( 2x²       + 1 )
-------------------------------------------------------------
                      2x  + 2
```
