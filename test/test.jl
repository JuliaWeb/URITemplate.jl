using Base.Test
import URITemplate.expand

# Level 1 examples
l1 = {"var" => "value", "hello" => "Hello World!"}
@test expand("{var}",l1) == "value"
@test expand("{hello}",l1) == "Hello%20World%21"

# Level 2 examples
l2 = ["path" => "/foo/bar"]
merge!(l2,l1)
@test expand("{+hello}",l2) == "Hello%20World!"
@test expand("{+path}/here",l2) == "/foo/bar/here"
@test expand("here?ref={+path}",l2) == "here?ref=/foo/bar"
@test expand("X{#var}",l2) == "X#value"
@test expand("X{#hello}",l2) == "X#Hello%20World!"

# Level 3 examples
l3 = {"empty" => "", "x" => "1024", "y" => "768"}
merge!(l3,l2)
@test expand("map?{x,y}",l3) == "map?1024,768"
@test expand("{x,hello,y}",l3) == "1024,Hello%20World%21,768"
@test expand("{+x,hello,y}",l3) == "1024,Hello%20World!,768"
@test expand("{+path,x}/here",l3) == "/foo/bar,1024/here"
@test expand("{#x,hello,y}",l3) == "#1024,Hello%20World!,768"
@test expand("{#path,x}/here",l3) == "#/foo/bar,1024/here"
@test expand("X{.var}",l3) == "X.value"
@test expand("X{.x,y}",l3) == "X.1024.768"
@test expand("{/var}",l3) == "/value"
@test expand("{/var,x}/here",l3) == "/value/1024/here"
@test expand("{;x,y}",l3) == ";x=1024;y=768"
@test expand("{;x,y,empty}",l3) == ";x=1024;y=768;empty"
@test expand("{?x,y}",l3) == "?x=1024&y=768"
@test expand("{?x,y,empty}",l3) == "?x=1024&y=768&empty="
@test expand("?fixed=yes{&x}",l3) == "?fixed=yes&x=1024"
@test expand("{&x,y,empty}",l3) == "&x=1024&y=768&empty="

# Level 4 examples
l4 = ["list"=>["red", "green", "blue"],"keys"=>["semi"=>";","dot"=>".","comma"=>","]]
merge!(l4,l2)
@test expand("{var:3}",l4) == "val"
@test expand("{var:30}",l4) == "value"
@test expand("{list}",l4) == "red,green,blue"
@test expand("{list*}",l4) == "red,green,blue"

permcomma(a,c=',') = [join(x,c) for x in permutations(a)]

@test sort(split(expand("{keys}",l4),',')) == sort(["comma","%2c","semi","%3b","dot","."])
@test sort(split(expand("{keys*}",l4),',')) == sort(["comma=%2c","semi=%3b","dot=."])
@test expand("{+path:6}/here",l4) == "/foo/b/here"
@test expand("{+list}",l4) == "red,green,blue"
@test expand("{+list*}",l4) == "red,green,blue"
@test expand("{+keys}",l4) in permcomma(["comma,,","semi,;","dot,."])
@test expand("{+keys*}",l4) in permcomma(["comma=,","semi=;","dot=."])
@test expand("{#path:6}/here",l4) == "#/foo/b/here"
@test expand("{#list}",l4) == "#red,green,blue"
@test expand("{#list*}",l4) == "#red,green,blue"
@test expand("{#keys}",l4) in [string("#",x) for x in permcomma(["comma,,","semi,;","dot,."])]
@test expand("{#keys*}",l4) in [string("#",x) for x in permcomma(["comma=,","semi=;","dot=."])]
@test expand("X{.var:3}",l4) == "X.val"
@test expand("X{.list}",l4) == "X.red,green,blue"
@test expand("X{.list*}",l4) == "X.red.green.blue"
@test expand("X{.keys}",l4) in [string("X.",x) for x in permcomma(["comma,%2c","semi,%3b","dot,."])]
@test expand("X{.keys*}",l4) in [string("X.",x) for x in permcomma(["comma=%2c","semi=%3b","dot=."],'.')]
@test expand("{/var:1,var}",l4) == "/v/value"
@test expand("{/list}",l4) == "/red,green,blue"
@test expand("{/list*}",l4) == "/red/green/blue"
@test expand("{/list*,path:4}",l4) == "/red/green/blue/%2ffoo"
@test expand("{/keys}",l4) in [string("/",x) for x in permcomma(["comma,%2c","semi,%3b","dot,."])]
@test expand("{/keys*}",l4) in [string("/",x) for x in permcomma(["comma=%2c","semi=%3b","dot=."],'/')]
@test expand("{;hello:5}",l4) == ";hello=Hello"
@test expand("{;list}",l4) == ";list=red,green,blue"
@test expand("{;list*}",l4) == ";list=red;list=green;list=blue"
@test expand("{;keys}",l4) in [string(";keys=",x) for x in permcomma(["comma,%2c","semi,%3b","dot,."])]
@test expand("{;keys*}",l4) in [string(";",x) for x in permcomma(["comma=%2c","semi=%3b","dot=."],';')]
@test expand("{?var:3}",l4) == "?var=val"
@test expand("{?list}",l4) == "?list=red,green,blue"
@test expand("{?list*}",l4) == "?list=red&list=green&list=blue"
@test expand("{?keys}",l4) in [string("?keys=",x) for x in permcomma(["comma,%2c","semi,%3b","dot,."])]
@test expand("{?keys*}",l4) in [string("?",x) for x in permcomma(["comma=%2c","semi=%3b","dot=."],'&')]
@test expand("{&var:3}",l4) == "&var=val"
@test expand("{&list}",l4) == "&list=red,green,blue"
@test expand("{&list*}",l4) == "&list=red&list=green&list=blue"
@test expand("{&keys}",l4) in [string("&keys=",x) for x in permcomma(["comma,%2c","semi,%3b","dot,."])]
@test expand("{&keys*}",l4) in [string("&",x) for x in permcomma(["comma=%2c","semi=%3b","dot=."],'&')]