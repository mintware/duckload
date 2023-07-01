@set PROG=duckload
@if "%1"=="clean" goto clean
@if "%1"=="dist" goto dist
	nasm -f bin -o %PROG%.com -l %PROG%.lst %PROG%.asm
	@goto end
:dist
	pkzip %PROG%.zip %PROG%.com
	@goto end
:clean
	del %PROG%.lst
	del %PROG%.map
	del %PROG%.com
	del %PROG%.zip
:end
