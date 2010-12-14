EESchema Schematic File Version 2  date 2010-12-14T20:47:45 CET
LIBS:enc28j60
LIBS:power
LIBS:device
LIBS:transistors
LIBS:conn
LIBS:linear
LIBS:regul
LIBS:74xx
LIBS:cmos4000
LIBS:adc-dac
LIBS:memory
LIBS:xilinx
LIBS:special
LIBS:microcontrollers
LIBS:dsp
LIBS:microchip
LIBS:analog_switches
LIBS:motorola
LIBS:texas
LIBS:intel
LIBS:audio
LIBS:interface
LIBS:digital-audio
LIBS:philips
LIBS:display
LIBS:cypress
LIBS:siliconi
LIBS:opto
LIBS:atmel
LIBS:contrib
LIBS:valves
LIBS:bc807
LIBS:bc817
LIBS:amp-rj45-tap-up-with-leds
LIBS:l4960
LIBS:borniers
LIBS:g5sb
LIBS:doorctrl-v4-cache
EELAYER 24  0
EELAYER END
$Descr A4 11700 8267
Sheet 4 5
Title ""
Date "14 dec 2010"
Rev ""
Comp ""
Comment1 ""
Comment2 ""
Comment3 ""
Comment4 ""
$EndDescr
Connection ~ 2250 4400
Connection ~ 3650 3250
Wire Wire Line
	3650 3250 3650 4400
Wire Wire Line
	3650 4400 2250 4400
Wire Wire Line
	2250 4500 2250 4300
Connection ~ 3700 3650
Connection ~ 2050 5150
Wire Wire Line
	3700 5150 1200 5150
Wire Wire Line
	3700 5150 3700 3650
Connection ~ 3500 3650
Wire Wire Line
	1100 3650 3850 3650
Connection ~ 3500 3250
Wire Wire Line
	3350 3250 3850 3250
Connection ~ 2600 3250
Wire Wire Line
	2750 3250 2450 3250
Wire Wire Line
	2050 5150 2050 3600
Wire Wire Line
	1650 3600 1650 4150
Wire Wire Line
	1250 3250 1100 3250
Connection ~ 1850 5150
Wire Wire Line
	1650 4650 1650 4750
Wire Wire Line
	1200 5150 1200 4700
Connection ~ 4450 1600
Connection ~ 6900 1600
Wire Wire Line
	3550 1600 7150 1600
Connection ~ 6400 1600
Connection ~ 5900 1600
Connection ~ 5400 1600
Connection ~ 4900 1600
Connection ~ 6650 2000
Connection ~ 6150 2000
Connection ~ 5650 2000
Connection ~ 4900 2000
Connection ~ 4250 2000
Connection ~ 3650 2000
Connection ~ 4250 1600
Connection ~ 3950 1600
Wire Wire Line
	2700 1300 2700 1750
Wire Wire Line
	2700 1750 2500 1750
Wire Wire Line
	1650 2050 1650 2150
Wire Wire Line
	800  1900 800  1700
Connection ~ 800  1000
Wire Wire Line
	1000 1000 800  1000
Wire Wire Line
	800  750  2500 750 
Wire Wire Line
	800  750  800  1400
Wire Wire Line
	1650 1050 1650 950 
Wire Wire Line
	2500 750  2500 1450
Connection ~ 2500 1350
Wire Wire Line
	1500 1000 1650 1000
Connection ~ 1650 1000
Wire Wire Line
	800  2300 800  2450
Wire Wire Line
	2500 2350 2500 2450
Wire Wire Line
	2500 1750 2500 1850
Connection ~ 2500 1750
Wire Wire Line
	2500 1600 2950 1600
Connection ~ 2850 1600
Wire Wire Line
	3200 1300 4450 1300
Connection ~ 3650 1600
Connection ~ 4450 1300
Connection ~ 3950 2000
Connection ~ 4650 2000
Connection ~ 5150 2000
Connection ~ 5900 2000
Connection ~ 6400 2000
Connection ~ 6900 2000
Wire Wire Line
	2850 2000 7150 2000
Connection ~ 5400 2000
Connection ~ 4650 1600
Connection ~ 5150 1600
Connection ~ 5650 1600
Connection ~ 6150 1600
Connection ~ 6650 1600
Wire Wire Line
	4450 2000 4450 2150
Connection ~ 4450 2000
Wire Wire Line
	4450 1200 4450 1600
Wire Wire Line
	1200 4200 1450 4200
Wire Wire Line
	1450 4600 1450 5150
Connection ~ 1450 5150
Wire Wire Line
	1850 5150 1850 4600
Connection ~ 1650 5150
Wire Wire Line
	1100 3250 1100 3050
Wire Wire Line
	1450 4200 1450 3600
Wire Wire Line
	1850 3600 1850 4200
Wire Wire Line
	3850 3250 3850 3050
Connection ~ 2600 3650
Wire Wire Line
	3850 3650 3850 3800
Wire Wire Line
	2250 5000 2250 5150
Connection ~ 2250 5150
Wire Wire Line
	2250 3800 2250 3600
$Comp
L R R29
U 1 1 4D04D9A5
P 2250 4050
F 0 "R29" V 2330 4050 50  0000 C CNN
F 1 "6k2" V 2250 4050 50  0000 C CNN
	1    2250 4050
	1    0    0    -1  
$EndComp
$Comp
L R R30
U 1 1 4D04D99F
P 2250 4750
F 0 "R30" V 2330 4750 50  0000 C CNN
F 1 "4k7" V 2250 4750 50  0000 C CNN
	1    2250 4750
	1    0    0    -1  
$EndComp
$Comp
L GND #PWR033
U 1 1 4D04D8EB
P 3850 3800
F 0 "#PWR033" H 3850 3800 30  0001 C CNN
F 1 "GND" H 3850 3730 30  0001 C CNN
	1    3850 3800
	1    0    0    -1  
$EndComp
$Comp
L +12V #PWR034
U 1 1 4D04D8CC
P 3850 3050
F 0 "#PWR034" H 3850 3000 20  0001 C CNN
F 1 "+12V" H 3850 3150 30  0000 C CNN
	1    3850 3050
	1    0    0    -1  
$EndComp
$Comp
L C C16
U 1 1 4D04D8AA
P 3850 3450
F 0 "C16" H 3900 3550 50  0000 L CNN
F 1 "100nF" H 3900 3350 50  0000 L CNN
	1    3850 3450
	1    0    0    -1  
$EndComp
$Comp
L DIODESCH D2
U 1 1 4D04D88B
P 2600 3450
F 0 "D2" H 2600 3550 40  0000 C CNN
F 1 "SK 86" H 2600 3350 40  0000 C CNN
	1    2600 3450
	0    1    1    0   
$EndComp
$Comp
L INDUCTOR L1
U 1 1 4D04D880
P 3050 3250
F 0 "L1" V 3000 3250 40  0000 C CNN
F 1 "220uH" V 3150 3250 40  0000 C CNN
	1    3050 3250
	0    -1   -1   0   
$EndComp
$Comp
L R R26
U 1 1 4D04D801
P 1200 4450
F 0 "R26" V 1280 4450 50  0000 C CNN
F 1 "4k7" V 1200 4450 50  0000 C CNN
	1    1200 4450
	1    0    0    -1  
$EndComp
$Comp
L R R28
U 1 1 4D04D7F1
P 1650 4400
F 0 "R28" V 1700 4650 50  0000 C CNN
F 1 "15k" V 1650 4400 50  0000 C CNN
	1    1650 4400
	1    0    0    -1  
$EndComp
$Comp
L C C13
U 1 1 4D04D7E8
P 1850 4400
F 0 "C13" V 1900 4550 50  0000 L CNN
F 1 "2.2uF" V 1900 4250 50  0000 L CNN
	1    1850 4400
	1    0    0    -1  
$EndComp
$Comp
L C C12
U 1 1 4D04D7D1
P 1650 4950
F 0 "C12" V 1700 5100 50  0000 L CNN
F 1 "33nF" V 1550 5100 50  0000 L CNN
	1    1650 4950
	1    0    0    -1  
$EndComp
$Comp
L C C11
U 1 1 4D04D7C7
P 1450 4400
F 0 "C11" V 1500 4550 50  0000 L CNN
F 1 "2.2nF" V 1500 4250 50  0000 L CNN
	1    1450 4400
	1    0    0    -1  
$EndComp
$Comp
L +24V #PWR035
U 1 1 4D04D7BB
P 1100 3050
F 0 "#PWR035" H 1100 3000 20  0001 C CNN
F 1 "+24V" H 1100 3150 30  0000 C CNN
	1    1100 3050
	1    0    0    -1  
$EndComp
$Comp
L CAPAPOL C14
U 1 1 4D04D79B
P 3500 3450
F 0 "C14" H 3350 3550 50  0000 L CNN
F 1 "1000uF" H 3200 3350 50  0000 L CNN
	1    3500 3450
	1    0    0    -1  
$EndComp
$Comp
L CAPAPOL C10
U 1 1 4D04D797
P 1100 3450
F 0 "C10" H 950 3550 50  0000 L CNN
F 1 "1200uF" H 800 3350 50  0000 L CNN
	1    1100 3450
	1    0    0    -1  
$EndComp
$Comp
L L4960 U3
U 1 1 4D04D789
P 1850 3250
F 0 "U3" H 1800 3500 50  0000 L BNN
F 1 "L4960" H 1700 3250 50  0000 L BNN
F 2 "l4960-HEPTAWATT" H 1850 3350 50  0001 C CNN
	1    1850 3250
	1    0    0    -1  
$EndComp
Text Notes 5100 1500 0    60   ~ 0
Distributed decoupling capacitors
$Comp
L GND #PWR036
U 1 1 4D04D42D
P 4450 2150
F 0 "#PWR036" H 4450 2150 30  0001 C CNN
F 1 "GND" H 4450 2080 30  0001 C CNN
	1    4450 2150
	1    0    0    -1  
$EndComp
$Comp
L C C29
U 1 1 4D04D3B3
P 7150 1800
F 0 "C29" H 7200 1900 50  0000 L CNN
F 1 "100nF" H 7100 1550 50  0000 L CNN
	1    7150 1800
	1    0    0    -1  
$EndComp
$Comp
L C C28
U 1 1 4D04D3B1
P 6900 1800
F 0 "C28" H 6950 1900 50  0000 L CNN
F 1 "100nF" H 6850 1550 50  0000 L CNN
	1    6900 1800
	1    0    0    -1  
$EndComp
$Comp
L C C27
U 1 1 4D04D3AE
P 6650 1800
F 0 "C27" H 6700 1900 50  0000 L CNN
F 1 "100nF" H 6600 1550 50  0000 L CNN
	1    6650 1800
	1    0    0    -1  
$EndComp
$Comp
L C C26
U 1 1 4D04D3A1
P 6400 1800
F 0 "C26" H 6450 1900 50  0000 L CNN
F 1 "100nF" H 6350 1550 50  0000 L CNN
	1    6400 1800
	1    0    0    -1  
$EndComp
$Comp
L C C25
U 1 1 4D04D39E
P 6150 1800
F 0 "C25" H 6200 1900 50  0000 L CNN
F 1 "100nF" H 6100 1550 50  0000 L CNN
	1    6150 1800
	1    0    0    -1  
$EndComp
$Comp
L C C24
U 1 1 4D04D39B
P 5900 1800
F 0 "C24" H 5950 1900 50  0000 L CNN
F 1 "100nF" H 5850 1550 50  0000 L CNN
	1    5900 1800
	1    0    0    -1  
$EndComp
$Comp
L C C23
U 1 1 4D04D398
P 5650 1800
F 0 "C23" H 5700 1900 50  0000 L CNN
F 1 "100nF" H 5600 1550 50  0000 L CNN
	1    5650 1800
	1    0    0    -1  
$EndComp
$Comp
L C C22
U 1 1 4D04D394
P 5400 1800
F 0 "C22" H 5450 1900 50  0000 L CNN
F 1 "100nF" H 5350 1550 50  0000 L CNN
	1    5400 1800
	1    0    0    -1  
$EndComp
$Comp
L C C21
U 1 1 4D04D38F
P 5150 1800
F 0 "C21" H 5200 1900 50  0000 L CNN
F 1 "100nF" H 5100 1550 50  0000 L CNN
	1    5150 1800
	1    0    0    -1  
$EndComp
$Comp
L C C20
U 1 1 4D04D38C
P 4900 1800
F 0 "C20" H 4950 1900 50  0000 L CNN
F 1 "100nF" H 4850 1550 50  0000 L CNN
	1    4900 1800
	1    0    0    -1  
$EndComp
$Comp
L C C19
U 1 1 4D04D33D
P 4650 1800
F 0 "C19" H 4700 1900 50  0000 L CNN
F 1 "100nF" H 4600 1550 50  0000 L CNN
	1    4650 1800
	1    0    0    -1  
$EndComp
$Comp
L C C18
U 1 1 4D04D22A
P 4250 1800
F 0 "C18" H 4300 1900 50  0000 L CNN
F 1 "10uF" H 4300 1700 50  0000 L CNN
	1    4250 1800
	1    0    0    -1  
$EndComp
$Comp
L +3.3V #PWR037
U 1 1 4D04D218
P 4450 1200
F 0 "#PWR037" H 4450 1160 30  0001 C CNN
F 1 "+3.3V" H 4450 1310 30  0000 C CNN
	1    4450 1200
	1    0    0    -1  
$EndComp
$Comp
L CAPAPOL C17
U 1 1 4D04D1BD
P 3950 1800
F 0 "C17" H 4000 1900 50  0000 L CNN
F 1 "100uF" H 4000 1700 50  0000 L CNN
	1    3950 1800
	1    0    0    -1  
$EndComp
$Comp
L CAPAPOL C15
U 1 1 4D04D0AE
P 3650 1800
F 0 "C15" H 3700 1900 50  0000 L CNN
F 1 "100uF" H 3700 1700 50  0000 L CNN
	1    3650 1800
	1    0    0    -1  
$EndComp
$Comp
L INDUCTOR L2
U 1 1 4D04CFE3
P 3250 1600
F 0 "L2" V 3200 1600 40  0000 C CNN
F 1 "330uH" V 3350 1600 40  0000 C CNN
	1    3250 1600
	0    -1   -1   0   
$EndComp
$Comp
L DIODESCH D3
U 1 1 4D04CF74
P 2850 1800
F 0 "D3" H 2850 1900 40  0000 C CNN
F 1 "SK 34SMA" H 2850 1700 40  0000 C CNN
	1    2850 1800
	0    -1   -1   0   
$EndComp
$Comp
L C C9
U 1 1 4D04CF13
P 800 2100
F 0 "C9" H 850 2200 50  0000 L CNN
F 1 "82pF" H 850 2000 50  0000 L CNN
	1    800  2100
	1    0    0    -1  
$EndComp
$Comp
L GND #PWR038
U 1 1 4D04CF0D
P 800 2450
F 0 "#PWR038" H 800 2450 30  0001 C CNN
F 1 "GND" H 800 2380 30  0001 C CNN
	1    800  2450
	1    0    0    -1  
$EndComp
$Comp
L GND #PWR039
U 1 1 4D04CF06
P 2500 2450
F 0 "#PWR039" H 2500 2450 30  0001 C CNN
F 1 "GND" H 2500 2380 30  0001 C CNN
	1    2500 2450
	1    0    0    -1  
$EndComp
$Comp
L GND #PWR040
U 1 1 4D04CF02
P 1650 2150
F 0 "#PWR040" H 1650 2150 30  0001 C CNN
F 1 "GND" H 1650 2080 30  0001 C CNN
	1    1650 2150
	1    0    0    -1  
$EndComp
$Comp
L R R32
U 1 1 4D04CED4
P 2950 1300
F 0 "R32" V 3030 1300 50  0000 C CNN
F 1 "18k" V 2950 1300 50  0000 C CNN
	1    2950 1300
	0    1    1    0   
$EndComp
$Comp
L R R31
U 1 1 4D04CEB9
P 2500 2100
F 0 "R31" V 2580 2100 50  0000 C CNN
F 1 "11k" V 2500 2100 50  0000 C CNN
	1    2500 2100
	1    0    0    -1  
$EndComp
$Comp
L R R27
U 1 1 4D04CE98
P 1250 1000
F 0 "R27" V 1330 1000 50  0000 C CNN
F 1 "0.22R" V 1250 1000 50  0000 C CNN
	1    1250 1000
	0    1    1    0   
$EndComp
$Comp
L +24V #PWR041
U 1 1 4D04CE42
P 1650 950
F 0 "#PWR041" H 1650 900 20  0001 C CNN
F 1 "+24V" H 1650 1050 30  0000 C CNN
	1    1650 950 
	1    0    0    -1  
$EndComp
$Comp
L MC34063 U2
U 1 1 4D04CE01
P 1650 1550
F 0 "U2" H 1800 1900 60  0000 L CNN
F 1 "MC34063" H 1750 1200 60  0000 L CNN
	1    1650 1550
	1    0    0    -1  
$EndComp
$EndSCHEMATC
