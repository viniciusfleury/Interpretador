function foo()
begin
 print(x)
 ret = 3
end
function main()
 var x
begin
 x = 5
 x = foo()
 print(x)
end
