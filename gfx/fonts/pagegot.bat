@echo off
set inputFile=D:\Aenyrag\hoi4\hoi4\Hearts of Iron IV\Paradox Interactive\Hearts of Iron IV\mod\Atropos\gfx\fonts\mapfont_chn_x.fnt
set outputFile=D:\Aenyrag\hoi4\hoi4\Hearts of Iron IV\Paradox Interactive\Hearts of Iron IV\mod\Atropos\gfx\fonts\page=0.txt

:: 使用 findstr 命令搜索包含 "page=0" 的行，并输出到目标文件
findstr "page=0" "% inputFile%" > "% outputFile%"

echo 完成，结果已写入 % outputFile%
pause