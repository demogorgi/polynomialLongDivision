# polynomialLongDivision
Polynomial long divison in finite fields with command line and Latex output

Example:

>ruby pd.rb "3,0,0,1,1" "4,0,3" 5 x

yields (among other things):

  (   1x⁴ + 1x³ +      +      + 3  ) : (   3x² +      + 4  ) =    2x² + 2x  + 4
- (   1x⁴ +      + 3x² +      + )
-------------------------------------------------------------
            1x³ + 2x² +      +
      - (   1x³ +      + 3x  + )
-------------------------------------------------------------
                  2x² + 2x  + 3
            - (   2x² +      + 1 )
-------------------------------------------------------------
                        2x  + 2
