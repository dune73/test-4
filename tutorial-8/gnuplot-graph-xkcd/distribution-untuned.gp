set boxwidth 0.5
set term pngcairo size 1600,900 font 'Humor Sans,28' background rgb 'white'
	# -> debian font package: fonts-humor-sans

set output 'distribution-untuned.png'

reset
unset key
set style data histogram
set style histogram cluster gap 1
set style fill solid border -1
set boxwidth 0.9
set xtic scale 0
#set ytic(50)
unset ytics
#set ytics (0, 10, 20, 25, 30, 40, 50, 60, 70, 80, 90, 100)
set xtics  offset -0.25,graph 0 (0, 2, 4, 6, 8, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60 , 65, 70, 75, 80, 85, 90, 95, 100)
set xrange [-0.3:100.5]
set yrange [0:5500]
#unset xrange  
#unset xtics
set border 3
set lmargin 8
set xlabel "Number of Requests per Anomaly Score"
set size 1, 1
set label 1 "none" at -1,0.0 right
set label 2 "some" at -1,1500 right
set label 3 "some\nmore" at -1,3000 right
set label 4 "a lot" at -1,4200 right
set label 5 "bloody\nmany" at -1,5500 right
set label 6 "Outlier\nway to the right\n(Score 171!!!)" at 85, 3400 right
set label 7 "Anomaly Score Distribution" at 70, 5400 right
set arrow 1 from 86,3150 to 102,2200 head filled linewidth 2
plot 'distribution-untuned.dat' u 2 title ' ' linecolor rgb "#00EE00"
