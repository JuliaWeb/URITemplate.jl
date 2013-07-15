This package provides URI Template interpolation by implementing. (RFC 6570)[ttp://tools.ietf.org/html/rfc6570]. The only interface to this function is the expand method which may be invoked as

```julia
	URITemplate.expand(template,variables)
```

e.g:

```julia
vars = {"var" => "value", "hello" => "Hello World!","list"=>["red", "green", "blue"]}
URITemplate.expand("{var}",vars) # "value"
URITemplate.expand("{hello}",vars) # "Hello%20World%21"
URITemplate.expand("{?list*}",vars) == "?list=red&list=green&list=blue"
```

This package is supposed to conform to the above mentioned RFC. If you find
a case in which is does not, please open an Issue. 

