<?php

  exec('montage ../images/markers/*-marker-*-sm.png -background none -tile x1 -geometry 66x66+1+1 _marker-sprite-sm.png');
  exec('montage ../images/markers/*-marker-*-lg.png -background none -tile x1 -geometry 66x66+1+1 _marker-sprite-lg.png'); // -tile 78x



/*
$files = glob("../images/markers/marker-*-*-*.png");
$num=count($files);
$i=1;
foreach ( $files as $filename) {
//    $n=str_pad($i, $num ,"0",STR_PAD_LEFT);
    
    $path_parts = pathinfo($filename); 
    $array = explode('-', $path_parts['filename']);
    $newfile = $array[3].'-'.$array[0].'-'.$array[1].'-'.$array[2].'.png';
//    rename($filename,$newfile);
    echo $newfile.'<br />';
    
    $i+=1;
}
*/

?>