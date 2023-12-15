require 'prime'
require 'pp'

# polynomial long division in finite fields by Uwe Gotzes 
#
# Invocation:
# >ruby pd.rb "3,0,0,1,1" "4,0,3" 5 x
#
# Arguments: Dividend, divisor, characteristic of the finite field, variable symbol
#

if ARGV.length < 2
	puts "Invocation:"
	puts ">ruby pd.rb \"3,0,0,1,1\" \"4,0,3\" 5 x"
	puts "Arguments: Dividend, divisor, characteristic of the finite field, variable symbol"
        puts "If 1 is used for the characteristic computations will be done within the real numbers!"
end

# Anpassungen an Array für die Interpretation als Polynom mit Koeffizienten in Z/pZ
class Array
	def deg
		length-1
	end

	def maxLen
		map{ |x| x.to_s.length }.max
	end

	# für Latex-Ausgabe
	# macht aus [nil,1,0,3,5] -> ["5x^{4}","3x^{3}","0x^{2}","1x",nil]
	def preinspect
	    tmp = self.each_with_index.map{ |x,i| 
		if x.nil?
		else
		    if i == 0
			x.to_s
		    elsif i == 1
			x.to_s + "#{X}"
		    else
			x.to_s + "#{X}^{#{i}}"
		    end
		end
	    }.reverse
	    res = tmp
	    # macht aus ["5x^{4}","3x^{3}","0x^{2}","1x",nil] -> ["5x^{4}","3x^{3}",nil,"x",nil]
	    tmp.each_with_index{ |x,i|
		if x.nil? or x[0] == "0"
		    res[i] = nil
		elsif x =~ /^1#{X}/
		    res[i] = x[1..-1]
		else
		    res[i] = x
		end
	    }
	    res
	end

	# für stdout
	def inspect(r=R,s=" ",var=X)
		# macht aus [nil,1,0,3,5] -> ["5x\u2074", "3x\u00B3", nil, "x", nil]
		tmp = preinspect.map{ |x| 
		    if x =~ /\^{(.*)}/
			x.sub(/\^{(.*)}/,hoch(x.match(/\^{(.*)}/)[1]))
		    else
			x
		    end
		}
		res = ""
		# macht aus tmp den String für stdout
		tmp.each_with_index{ |x,i|
		    if x.nil?
			res += "   " + "".rjust(r,s)
		    elsif i == 0
			res += "   " + x.rjust(r,s)
		    elsif tmp[0..(i-1)].any?{|d| d != nil}
			res += " + " + x.rjust(r,s)
		    else
			res += "   " + x.rjust(r,s)
		    end
		}
		res
	end

	def latex(str=nil)
		new_ary = []
		each_with_index.map{ |x,i|	
			if x.nil?
				new_ary.push ["&","&"]
			elsif i == 0
				new_ary.push ["&",str,"&",self[i]]
			elsif (self[0..i-1].all? &:nil?) and self[i] != nil
				new_ary.push ["&",str,"&",self[i]]
			elsif self[i] != nil
				new_ary.push ["&","+","&",self[i]]
			end
			if self[i] != nil and self[i+1..-1].all? &:nil? and str
				new_ary.push ["&",")"]
			end
		}
		new_ary.flatten.join(" ")
	end

	def mod(p=P)
          if p == 1
            self
          else
	    map{ |x| x % p }
          end
	end
end

# Variablensymbol
if ARGV[3]
	X = ARGV[3]
else
	X = "x"
end

# Charakteristik des Primzahlkörpers Z/pZ
P = ARGV[2].to_i

# Fehlerbehandlung
if P.to_s != ARGV[2] and ( P != 1 or !(Prime.prime?(P)) )
	raise ArgumentError, "#{ARGV[2]} ist weder 1 noch eine Primzahl."
end

# Polynome in Z/pZ in der
dividend = ARGV[0].split(",").map{ |x| P == 1 ? x.to_f : x.to_i }.mod
divisor = ARGV[1].split(",").map{ |x| P == 1 ? x.to_f : x.to_i }.mod
D = dividend.clone
R = D.preinspect.maxLen

# Fehlerbehandlung
if dividend.deg < divisor.deg
	raise ArgumentError, "Grad von Divisor ist größer als Grad von Dividend."
end

# Fehlerbehandlung
if dividend.last == 0 or divisor.last == 0
	raise ArgumentError, "Die Listen dürfen nicht mit 0 enden. Höchste Potenz darf (modulo #{P}) nicht 0 sein."
end

# inverses Element bzgl. Multiplikation
def inverses(num, p=P)
  if p == 1
    1.0 / num
  else
    (0..p-1).to_a.map{ |x| ( x * num ) % p == 1 }.find_index{ |b| b == true }
  end
end

def hoch(string)
	if string.to_i.to_s != string
		raise ArgumentError, "String \"#{string}\" sieht nicht aus wie ein Integer mit Anführungsstrichen."
	end
	string.split("").map do |c|
		if c == "0"
			"\u2070"
		elsif c == "1"
			"\u00B9"
		elsif c == "2"
			"\u00B2"
		elsif c == "3"
			"\u00B3"
		elsif c == "4"
			"\u2074"
		elsif c == "5"
			"\u2075"
		elsif c == "6"
			"\u2076"
		elsif c == "7"
			"\u2077"
		elsif c == "8"
			"\u2078"
		elsif c == "9"
			"\u2079"
		else
			raise ArgumentError
		end
	end.join()
end

# Koeffizient höchste Potenz Dividend geteilt durch Koeffizient höchste Potenz Divisor; Rückgabe als Array
def teile(dividend, divisor)
	d = Array.new(dividend.deg - divisor.deg + 1, 0)
	d[-1] = dividend.last * inverses(divisor.last)
	d.mod
end

# Polynomaddition; Rückgabe als Array
def polyadd(summand1, summand2)
	sum = summand1.each_with_index.map{ |x,i| x + summand2[i] }
	sum.mod
end

# Polynommultiplikation; Rückgabe als Array
def polymult(a, b)
	a_tmp = a.clone
	b_tmp = b.clone
	degc = a.deg + b.deg + 1
	(degc - a.deg - 1).times{ a_tmp << 0 }
	(degc - b.deg - 1).times{ b_tmp << 0 }
	c = Array.new(degc, 0)
	c.each_index{ |k|
		a.each_index{ |i| c[k] += a_tmp[i] * b_tmp[k-i] }
	}
	c.mod
end

# wovon wird abgezogen
def minuend(p,dividend)
	m = Array.new(p.deg,0) + dividend[p.deg..-1]
	m.mod
end

# Holt Koeffizienten von dividend nach p
def runterholen(p,q,dividend)
	p[q.deg-1] = dividend[q.deg-1]
	p[0..-2].mod
end

def fill(ary,int=D.deg)
	ary_tmp = ary.clone
	(D.deg - ary.deg).times{ ary_tmp << nil }
	ary_tmp
end

# Hauptprogramm schriftlich dividieren in Z/pZ
loesung = Array.new(dividend.deg-divisor.deg+1)
i = 0
stringoutput = []
latexoutput = [
	"\\documentclass{report}",
	"\\usepackage[landscape=true]{geometry}",
	"\\begin{document}",
	"$\\begin{array}{#{"r" * (2 * D.deg + 6)}}"
]
until dividend.deg < divisor.deg do
	i += 1
	puts "--------"
	print "dividend: "
	pp dividend.preinspect
	print "divisor: "
	pp divisor.preinspect
	print "Ergebnis teile: "
	pp t1 = teile(dividend, divisor)
	loesung[-i] = t1[-1]
	print "Lösung: "
	pp loesung
	print "Ergebnis polymult: "
	pp t2 = polymult(t1,divisor)
	stringoutput << ("   " + " " * R) * (i-1) + " -(#{t2.inspect})".sub(/\s+\)/,")")
	latexoutput << fill(t2).preinspect.latex("-(") + "\\\\\\cline{#{2*i}-#{2*i+3*divisor.deg-1}}\\\\[-1.5ex]"
	stringoutput << "-------------------------------------------------------------"
	print "Ergebnis minuend: "
	pp t3 = minuend(t1,dividend)
	print "Ergebnis polyadd: "
	pp t4 = polyadd(t3,polymult([-1],t2))
	print "Ergebnis runterholen: "
	pp dividend = runterholen(t4,t1,D)
	stringoutput << "   " + ("   " + " " * R) * i + "#{dividend.inspect}"
	latexoutput << fill(dividend).preinspect.latex() + " &   & \\\\"
end
stringoutput.insert(0, "  (#{D.inspect}) : (#{divisor.inspect}) = #{loesung.inspect}")
latexoutput += ["\\end{array}$","\\end{document}"]
latexoutput.insert(4,"#{D.preinspect.latex("(")} & & : (#{divisor.preinspect.latex.gsub("&","")}) = #{loesung.preinspect.latex.gsub("&","")} \\\\\\")
latexoutput = latexoutput.join("\n")
File.write("x.tex",latexoutput)
system("pdflatex x.tex")
if P == 1
  puts "\nschriftliche Division in R:\n\n"
else
  puts "\nschriftliche Division in Z/#{P}Z:\n\n"
end
puts stringoutput
puts "\n\n"
print "Also:"
puts "#{D.inspect} = (#{loesung.mod.inspect}) * (#{divisor.inspect}) + #{dividend.mod.inspect}"
