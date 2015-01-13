#creazione del simulatore
set ns [new Simulator]

#file di output per xgraph
set fx [open out_xgraph.tr w]

#creazione dei nodi
set  A  [$ns node]
set  B  [$ns node]
set  C  [$ns node]
set  D  [$ns node]

$A label "A"
$B label "B"
$C label "C"
$D label "D"

$A shape hexagon
$B shape square
$C shape square
$D shape hexagon

$A color red
$B color blue
$C color blue
$D color red

#creazione dei link bidirezionali tra i nodi A-B e C-D
$ns duplex-link $A $B 100Mb 1ms DropTail
$ns duplex-link $C $D 100Mb 1ms DropTail

#creazione dei link asimmetrici tra i nodi B-C e C-B
$ns simplex-link $B $C 7Mb 200ms DropTail
$ns simplex-link $C $B 480Kb 200ms DropTail

#errore dello 0.5%
set lossrate 0.005

#creazione del modello di errore tra B e C
set errorBC [new ErrorModel]
$errorBC unit EU_PKT
$errorBC set rate_ $lossrate
$errorBC ranvar [new RandomVariable/Uniform]
$errorBC drop-target [new Agent/Null]

#creazione del modello di errore tra C e B
set errorCB [new ErrorModel]
$errorCB unit EU_PKT
$errorCB set rate_ $lossrate
$errorCB ranvar [new RandomVariable/Uniform]
$errorCB drop-target [new Agent/Null]

#attach dei modelli di errore ai nodi B e C
$ns lossmodel $errorBC $B $C
$ns lossmodel $errorCB $C $B

#creazione degli agent per i nodi A e D
set agentAsend [new Agent/TCP]
set agentArec  [new Agent/TCPSink]
set agentDsend [new Agent/TCP]
set agentDrec  [new Agent/TCPSink]

#attach degli agent di invio e ricezione ai nodi A e D
$ns attach-agent $A $agentAsend
$ns attach-agent $A $agentArec
$ns attach-agent $D $agentDsend
$ns attach-agent $D $agentDrec

#connessione degli agent
$ns connect $agentAsend $agentDrec
$ns connect $agentDsend $agentArec

#creazione delle applicazioni FTP
set ftpAD [new Application/FTP]
set ftpDA [new Application/FTP]

#attach delle applicazioni FTP agli agent
$ftpAD attach-agent $agentAsend
$ftpDA attach-agent $agentDsend

set grandezzaCoda 2

#limitazioni delle code
$ns queue-limit $B $C $grandezzaCoda
$ns queue-limit $C $B $grandezzaCoda

#dimensioni dei dati da trasferire via FTP
set bytesAD [expr 100 * 1024 * 1024]
set bytesDA [expr 20  * 1024 * 1024]

#variabili per misurare i tempi di trasferimento
set timeTotal 0
set timeSlice 0.1
set timeTest 0
set tempi(0) 0

#variabili per i test
set totTest 5
set nTest 1

#calcolo del numero di ack da ricevere [la dimensione di default di un pacchetto FTP è 1000]
set ackmaxAD [expr $bytesAD / [$agentAsend set packetSize_]]
set ackmaxDA [expr $bytesDA / [$agentDsend set packetSize_]]

proc checkProgression {} {
    global bytesAD bytesDA timeTotal timeSlice timeTest agentAsend agentDsend ackmaxAD ackmaxDA totTest nTest ftpAD ftpDA tempi fx B C grandezzaCoda
    set ns [Simulator instance]
    
    #puts "Inizio la procedura di check con il tempo $timeTotal"
    
    #setting dei timer
    set timeTotal [expr $timeTotal+$timeSlice]
    set timeTest [expr $timeTest+$timeSlice]
    
    #numero di ack ricevuti
    set ackRicAD [$agentAsend set ack_]
    set ackRicDA [$agentDsend set ack_]
    
    #se sono arrivati tutti gli ack di entrambi i trasferimenti
    if {$ackRicAD >= $ackmaxAD && $ackRicDA >= $ackmaxDA} {
	    
	    puts "Il test $nTest ha impiegato $timeTest secondi"
	    
	    set tempi($nTest) $timeTest
	   
	    #controllo se tutti i test sono stati fatti
	    if {$nTest == $totTest} {
	        puts "Ho finito tutti i test"
	        
	        #valore del quantile 
	        set z 1.644854
	        
	        set somma 0
	        for {set i 1} {$i<=$totTest} {incr i} {
		    set somma [expr $somma + $tempi($i)]
		    
	        }
	        set media [expr $somma / $totTest]
	        
	        set varianza 0
	        for {set i 1} {$i<=$totTest} {incr i} {
		    set temp [expr $tempi($i) - $media]
		    set temp [expr $temp * $temp]
		    set varianza [expr $varianza + $temp]
	        }
	        set varianza [expr $varianza / $totTest]
	        set devStd [expr sqrt ($varianza)]
	        set estremo1 [expr $media - [expr $z * [expr $devStd / [expr sqrt($totTest)]]]]
	        set estremo2 [expr $media + [expr $z * [expr $devStd / [expr sqrt($totTest)]]]]
	        
	        puts "Media dei tempi $media"
	        puts "Varianza dei tempi $varianza"
	        puts "Dev std dei tempi $devStd"
	        puts "Intervallo $estremo1 - $estremo2"
	        
	        puts $fx "$media $grandezzaCoda"
	        
	        if {$grandezzaCoda == 20} {
		    $ns at $timeTotal "finish"
		 } else {
		    set timeTest 0
		    set nTest 1
		    set grandezzaCoda [expr $grandezzaCoda + 2]
		    
		    #limitazioni delle code
		    $ns queue-limit $B $C $grandezzaCoda
		    $ns queue-limit $C $B $grandezzaCoda
		    
		    puts "Inizio del test $nTest con grandezza coda $grandezzaCoda..."
		    $ns at $timeTotal "$ftpAD send $bytesAD"
		    $ns at $timeTotal "$ftpDA send $bytesDA"
		    $ns at $timeTotal "checkProgression"
		    $ns run
		 }
	    
	    } else {	   
	    
		set nTest [expr $nTest + 1]
		set timeTest 0
		puts "Inizio del test $nTest con grandezza coda $grandezzaCoda..."
		$ns at $timeTotal "$ftpAD send $bytesAD"
		$ns at $timeTotal "$ftpDA send $bytesDA"
		$ns at $timeTotal "checkProgression"
		$ns run
	    }
	   
	
    } else {

	#richiamo check
	$ns at $timeTotal "checkProgression"
    }
	
}

#procedura richiamata alla fine della simulazione di tutti i test
proc finish {} {
	global ns fx
	$ns flush-trace
	close $fx
	exec xgraph -geometry 800x400 -bg white -t "Tempi di trasferimento al variare della dimensione delle code" -x "Tempo" -y "Dim. coda" out_xgraph.tr &
	exit 0
}

puts "Inizio del test $nTest con grandezza coda $grandezzaCoda..."
$ns at 0.0 "$ftpAD send $bytesAD"
$ns at 0.0 "$ftpDA send $bytesDA"
$ns at 0.0 "checkProgression"
$ns run


