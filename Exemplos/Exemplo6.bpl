function foo()
begin
 print(x)
 x = 20
end
function bar(x)
begin
 x = 10 * x
 foo()
 print(x)
end
function main()
 var x
begin
 x = 5
 bar(x)
 print(x)
end
