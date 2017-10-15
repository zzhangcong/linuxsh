#!/bin/bash
for (( y=1;$y<= 9;y++ ))
do
	x=1
	until [ $x -gt $y ]
	do
	echo -ne "$x*$y=$[$y*$x]\t"
	let x++
	done
echo
echo
done
