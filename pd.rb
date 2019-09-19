require 'prime'

# polynomial long division in finite fields by Uwe Gotzes 
#
# Invocation:
# >ruby pd.rb "3,0,0,1,1" "4,0,3" 5 x
#
# Arguments: Dividend, divisor, charakteristic of the finite field, variable symbol
#

if ARGV.length < 2
	puts "Invocation:"
	puts ">ruby pd.rb \"3,0,0,1,1\" \"4,0,3\" 5 x"
	puts "Arguments: Dividend, divisor, charakteristic of the finite field, variable symbol"
end

# Anpassungen an Array für die Interpretation als Polynom mit Koeffizienten in Z/pZ
class Array
	def deg
		length-1
	end

	def preinspect(r=R,s=" ",var=X)
		self.each_with_index.map do |x,i| 
			if x.nil?
				"0".rjust(r,s)
			elsif i == self.deg
				"   " + (x.to_s).rjust(r,s)
			else
				(x.to_s).rjust(r,s)
			end + "#{X}^{#{i}}"
		end.reverse
	end

	def inspect(r=R,s=" ",var=X)
		puts preinspect(r,s,X).map{ |x| x.sub(/\^{(.*)}/,hoch(x.match(/\^{(.*)}/)[1])) }.join(" + ").gsub(/ ([ ]*)0#{var}./,'  \1   ').gsub("#{X}\u2070","  ").gsub("#{X}\u00B9 ","#{X}  ")
		preinspect(r,s,X).map{ |x| x.sub(/\^{(.*)}/,hoch(x.match(/\^{(.*)}/)[1])) }.join(" + ").gsub(/ \+([ ]*)0#{var}./,'  \1   ').gsub("#{X}\u2070","  ").gsub("#{X}\u00B9 ","#{X}  ")
	end

	def mod(p=P)
		map{ |x| x % p }
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
R = P.to_s.length

# Fehlerbehandlung
if P.to_s != ARGV[2] or !(Prime.prime?(P))
	raise ArgumentError, "#{ARGV[2]} ist keine Primzahl."
end

# Polynome in Z/pZ in der
dividend = ARGV[0].split(",").map{ |x| x.to_i  }.mod
divisor = ARGV[1].split(",").map{ |x| x.to_i }.mod
D = dividend.clone

# Fehlerbehandlung
if dividend.deg < divisor.deg
	raise ArgumentError, "Grad von Divisor ist größer als Grad von Dividend."
end

# Fehlerbehandlung
if dividend.last == 0 or divisor.last == 0
	raise ArgumentError, "Die Listen dürfen nicht mit 0 enden. Köchste Potenz darf nicht 0 sein."
end

# inverses Element bzgl. Multiplikation
def inverses(int, prime=P)
	(0..prime-1).to_a.map{ |x| ( x * int ) % prime == 1 }.find_index{ |b| b == true }
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
	(D.deg - ary.deg).times{ ary_tmp << 0 }
	ary_tmp
end

# Hauptprogramm schriftlich dividieren in Z/pZ
loesung = Array.new(dividend.deg-divisor.deg+1)
i = 0
stringoutput = []
latexoutput = "\\documentclass{report}\n\\usepackage[landscape=true]{geometry}\n\\begin{document}\n$\\begin{array}{#{"r" * (2 * D.deg + 6)}}\naufgabe\n"
until dividend.deg < divisor.deg do
	i += 1
	puts "--------"
	print "dividend: "
	p dividend
	print "divisor: "
	p divisor
	print "Ergebnis teile: "
	p t1 = teile(dividend, divisor)
	loesung[-i] = t1[-1]
	print "Lösung: "
	p loesung
	print "Ergebnis polymult: "
	p t2 = polymult(t1,divisor)
	stringoutput << ("   " + " " * R + "  ") * (i-1) + "- (#{t2.inspect})".sub(/\s+\)/," )")
	latexoutput << "&   & " + fill(t2).preinspect.join(" &   & ") + " &   & \\\\\\cline{#{2*i}-#{2*i+3*divisor.deg}}\\\\[-1.5ex]\n"
	stringoutput << "-------------------------------------------------------------"
	print "Ergebnis minuend: "
	p t3 = minuend(t1,dividend)
	print "Ergebnis polyadd: "
	p t4 = polyadd(t3,polymult([-1],t2))
	print "Ergebnis runterholen: "
	p dividend = runterholen(t4,t1,D)
	stringoutput << "   " + ("   " + " " * R + "  ") * i + "#{dividend.inspect}"
	latexoutput << "&   & " + fill(dividend).preinspect.join(" &   & ") + " &   & \\\\\n"
end
stringoutput.insert(0, "  (#{D.inspect}) : (#{divisor.inspect}) = #{loesung.inspect}")
latexoutput << "\\end{array}$\n\\end{document}"
latexoutput.sub!("aufgabe","& ( & #{D.preinspect.join(" &  & ")} & ) & : (#{divisor.preinspect.join(" + ")}) = #{loesung.preinspect.join(" + ")} \\\\\\")
latexoutput.gsub!(/ 0#{X}\^\{[0-9]*\}/,"     ")               # Koeffizient 0 -> Term löschen
latexoutput.gsub!(/(^[& ]+)(&(?=[ 0-9]).*line.*)/,'\1-(\2')   # "-(" an der richtigen Stelle einfügen
latexoutput.gsub!(/(&)([& ]+\\\\\\)/,'\1)\2')                 # ")" an der richtigen Stelle einfügen
latexoutput.gsub!(/ 1(#{X}\^\{[0-9]*\})/,'\1')                # Koeffizient 1 -> Koeffizient löschen
latexoutput.gsub!(/(&[ ]*)(&[ ]*[\w\d])/,'\1+\2')             # auf übelste Art die "+" einschleusen
latexoutput.gsub!(/#{X}\^\{0\}/,"   ")                        # Exponent 0 -> Monom löschen
latexoutput.gsub!(/#{X}\^\{1\} /,"#{X}   ")                   # Exponent 1 -> Exponent löschen
latexoutput.gsub!(/\+[ ]*\+/,"+")                             # zwei Plus hintereinander löschen (kann beim Divisor vorkommen)
latexoutput.gsub!(/^([& ]*)\+/,'\1')                          # auf übelste Art störende "+" wieder löschen
latexoutput.gsub!(/\+([& )]*\\)/,'\1')                        # auf übelste Art störende "+" wieder löschen
latexoutput.gsub!("-(&)","&")                                 # falls der Subtrahend leer ist
latexoutput.gsub!(/\+([& ]+\))/,'\1')                         # noch ein störendes "+" entfernen
File.write("x.tex",latexoutput)
system("pdflatex x.tex")
puts "\nschriftliche Division in Z/#{P}Z:\n\n"
puts stringoutput
puts "\n\n"
print "Also:"
puts "#{D.inspect} = (#{loesung.mod.inspect}) * (#{divisor.inspect}) + #{dividend.mod.inspect}"
puts latexoutput
