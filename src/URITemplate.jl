module URITemplate

	function is_valid_literal(ch)
		if ch > 0x80
			return true
		end
		return ch != '\'' && ch != '\<' && ch != '>' && ch != '<' && ch != '"' &&
			   ch != '^' && ch != '`' && ch != '{' && ch != '|' && ch != '}' && ch != '%'
	end

	ops = ['+','#','.','/',';','?','&','=',',','!','@','|']

	isunreserved(ch) = isalnum(ch) || ch == '-' || ch == '.' || ch == '_' || ch == '~'

    isreserved(ch) = ch == ':' || ch == '/' || ch == '?' || ch == '#' || ch == '[' ||
    				 ch == ']' || ch == '@' || ch == '!' || ch == '$' || ch == '&' ||
    				 ch == '\''|| ch == '(' || ch == ')' || ch == '*' || ch == '+' ||
    				 ch == ',' || ch == ';' || ch == '='

	pctencode(s::IO,c::UInt8) = write(s,'%',base(16,c,2))

	function pctencode(s::IO, c::Char, allowR = false)
	    if c < 0x80
	    	if isunreserved(c)
	    		write(s,c)
	    	elseif allowR && isreserved(c)
	    		write(s,c)
	    	else
	        	pctencode(s, uint8(c))
	        end
	        return 1
	    elseif c < 0x800
	        pctencode(s, uint8(( c >> 6          ) | 0xC0))
	        pctencode(s, uint8(( c        & 0x3F ) | 0x80))
	        return 2
	    elseif c < 0x10000
	        pctencode(s, uint8(( c >> 12         ) | 0xE0))
	        pctencode(s, uint8(((c >> 6)  & 0x3F ) | 0x80))
	        pctencode(s, uint8(( c        & 0x3F ) | 0x80))
	        return 3
	    elseif c < 0x110000
	        pctencode(s, uint8(( c >> 18         ) | 0xF0))
	        pctencode(s, uint8(((c >> 12) & 0x3F ) | 0x80))
	        pctencode(s, uint8(((c >> 6)  & 0x3F ) | 0x80))
	        pctencode(s, uint8(( c        & 0x3F ) | 0x80))
	        return 4
	    else
	        return pctencode(s, '\ufffd')
	    end
	end

	function pctencode(s::IO, string::AbstractString, allowR = false)
		for c in string
			pctencode(s,c,allowR)
		end
	end

	function is_valid_pctencoding(string,i)
		done(string,i) && return false
		(ch,i) = next(string,i)
		(!ishex(ch) || done(string,i)) && return false
		(ch,i) = next(string,i)
		!ishex(ch) && return false
		return true
	end

	if VERSION < v"0.4.0"
		# eltype of Dict is now pair and not a Tuple
		function keytype( dict )
			return eltype(dict)[1]
		end
		# Size hint is replaced by sizehint!
		sizehint! = sizehint
	end

	function expand(template::AbstractString,variables)
		if !( keytype( variables ) <: AbstractString)
			variables = [string(k) => v for (k,v) in variables]
		end

		out = IOBuffer()

		# As a heuristic the result will probably be about as long as the template
		# in either case it's probably not much shorter, so we can avoid spurious
		# allocation in the early phases, without too much overhead.
		sizehint!(out.data,sizeof(template))

		i = start(template)
		while !done(template,i)
			(ch,i) = next(template,i)
			if ch == '%' && !is_valid_pctencoding(template,i)
				error("'%' encountered but percent encoding sequence invalid")
			end
			if ch != '{'
				if !is_valid_literal(ch)
					error("Non-literal character '$ch' encountered!")
				end
				write(out,ch)
				continue
			end
			# Expression
			j = i
			while !done(template,i)
				(ch,i) = next(template,i)
				if ch == '}'
					break
				end
			end
			done(template,prevind(template,i)) && error("Template ended while scanning expression")
			#The expression excluding '{' and '}'
			ex = SubString(template,j,prevind(template,prevind(template,i)))
			isempty(ex) && error("Expression may not be empty!")
			(ch,j) = next(ex,start(ex))
			op = :NUL
			#   .------------------------------------------------------------------.
   			#	|          NUL     +      .       /       ;      ?      &      #   |
   			#	|------------------------------------------------------------------|
   			#	| first |  ""     ""     "."     "/"     ";"    "?"    "&"    "#"  |
   			#   | sep   |  ","    ","    "."     "/"     ";"    "&"    "&"    ","  |
   			#   | named | false  false  false   false   true   true   true   false |
   			#   | ifemp |  ""     ""     ""      ""      ""     "="    "="    ""   |
   			#   | allow |   U     U+R     U       U       U      U      U     U+R  |
   			#   `------------------------------------------------------------------'
			first = ""
			sep = ","
			named = false
			allowR = false
			ifemp = ""
			if ch == '+'
				op = :+
				allowR = true
			elseif ch == '.'
				first = "."
				sep = "."
				op = :.
			elseif ch == '/'
				first = "/"
				sep = "/"
				op = :/
			elseif ch == ';'
				first = ";"
				sep = ";"
				named = true
				op = :semicolon
			elseif ch == '?'
				first = "?"
				sep = "&"
				named = true
				ifemp = "="
				op = :?
			elseif ch == '&'
				first = "&"
				sep = "&"
				named = true
				ifemp = "="
				op = :&
			elseif ch == '#'
				first = "#"
				sep = ","
				op = :hash
				allowR = true
			elseif ch in ops
				error("Unimplemented template operator")
			end
			k = j
			if op != :NUL
				(ch,k) = next(ex,j)
				#k = nextind(ex,k)
			else
				j = prevind(ex,k)
			end

			first_defined = true
			#Process the list of variable names
			while true
				if done(ex,k) || (!isalnum(ch) && ch != '_' && ch != '.' && !(ch == '%' && is_valid_pctencoding(ex,j))) #End of variable name
					explode = false
					limitlength = false
					limit = 0
					if k > sizeof(ex)
						varend = sizeof(ex)
					else
						varend = prevind(ex,nextind(ex,k))
					end
					if ch == '*'
						explode = true
						if !done(ex,k)
							(ch,k) = next(ex,k)
							varend = prevind(ex,varend)
						end
						varend = prevind(ex,varend)
					elseif ch == ','
						varend = prevind(ex,prevind(ex,varend))
					elseif ch == ':'
						limitlength = true
						kl,l = k,0
						varend = prevind(ex,prevind(ex,varend))
						while !done(ex,k)
							l>3 && break
							(ch,k) = next(ex,k)
							if !('0' <= ch <= '9')
								break
							end
							l+=1
						end
						l == 0 && error("Zero-length : postfix not allowed")
						if done(ex,k)
							limit = parseint(ex[kl:sizeof(ex)],10)
						else
							limit = parseint(ex[kl:prevind(ex,prevind(ex,k))],10)
						end
					elseif !done(ex,k)
						error("Spurious characters past the end of expression.")
					end
					varname = ex[prevind(ex,nextind(ex,j)):varend]
					if !haskey(variables,varname)
						if done(ex,k)
							break
						end
						(ch,k) = next(ex,k)
					end
					if first_defined
						write(out,first)
						first_defined = false
					else
						write(out,sep)
					end
					val = variables[varname]
					if isa(val,AbstractString)
						if named
							write(out,varname)
							if isempty(val)
								write(out,ifemp)
							else
								write(out,'=')
							end
						end
						if limitlength
							l,m = 0,start(val)
							while l < limit && !done(val,m)
								(ch,m) = next(val,m)
								pctencode(out,ch,allowR)
								l+=1
							end
						else
							pctencode(out,val,allowR)
						end
					elseif !explode
						if named
							write(out,varname)
							if isempty(val)
								write(out,ifemp)
							else
								write(out,'=')
							end
						end
						f = true
						if isa(val,Associative)
							for (key,v) in val
								if !f
									print(out,',')
								else
									f = false
								end
								pctencode(out,key,allowR)
								write(out,',')
								pctencode(out,v,allowR)
							end
						else
							for v in val
								if !f
									print(out,',')
								else
									f = false
								end
								pctencode(out,v,allowR)
							end
						end
					else
						if named
							firstentry = true
							if isa(val,Associative)
								for (key,v) in val
									if !firstentry
										write(out,sep)
									else
										firstentry = false
									end
									write(out,key)
									if isempty(v)
										write(out,ifemp)
									else
										write(out,'=')
										pctencode(out,v)
									end
								end
							else
								for v in val
									if !firstentry
										write(out,sep)
									else
										firstentry = false
									end
									write(out,varname)
									if isempty(v)
										write(out,ifemp)
									else
										write(out,'=')
										pctencode(out,v)
									end
								end
							end
						elseif isa(val,Associative)
							f = true
							for (key,v) in val
								if !f
									print(out,sep)
								else
									f = false
								end
								pctencode(out,key,allowR)
								write(out,'=')
								pctencode(out,v,allowR)
							end
						else
							f = true
							for v in val
								if !f
									print(out,sep)
								else
									f = false
								end
								pctencode(out,v,allowR)
							end
						end
					end
					j=k
				end
				if done(ex,k)
					break
				end
				(ch,k) = next(ex,k)
			end
		end
		takebuf_string(out)
	end

end
