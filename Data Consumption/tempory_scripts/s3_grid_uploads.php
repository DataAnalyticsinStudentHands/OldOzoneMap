<?php
	ini_set("upload_tmp_dir","/home/ibreathe/mnt/tmp");
	ini_set('memory_limit', '512M');
	require 'AWSSDKforPHP/aws.phar';
	
	use Aws\Common\Aws;
	$aws = Aws::factory('/opt/aws/config.json');
	$client = $aws->get('S3');

	$base_dir = "./gridData";
	$base_upload_dir = "gridData";
	//$years = array_diff(scandir($base_dir), array('..', '.'));
	$years = array("2013");
	while ($year = array_shift($years)) {
		$months = array_diff(scandir("$base_dir/$year"), array('..', '.'));
		while ($month = array_shift($months)) {
			$days = array_diff(scandir("$base_dir/$year/$month"), array('..', '.'));
			while ($day = array_shift($days)) {
				try {
					$filename = "$year$month$day.tar";
					$tmppath = "tmp/$filename";
                                	echo "\r$tmppath                 \r";				
					if (file_exists($tmppath)) {
					    unlink($tmppath);
					}
					if (file_exists("$tmppath.gz")) {
					    unlink("$tmppath.gz");
				}
				$day_tar = new PharData($tmppath);
				$day_tar->buildFromDirectory("$base_dir/$year/$month/$day",'/\.js$/');
                		$day_tar->compress(Phar::GZ);
				$client->putObject(array(
				    'Bucket'     => "uhcan",
				    'Key'        => "$base_upload_dir/$year/$month/$filename.gz",
				    'SourceFile' => "$tmppath.gz"
				));

				$client->waitUntilObjectExists(array(
				    'Bucket' => "uhcan",
				    'Key'    => "$base_upload_dir/$year/$month/$filename.gz"
				));
				
				unlink($tmppath);
                                unlink("$tmppath.gz");
				unset($day_tar);
				Phar::unlinkArchive($tmppath);
				Phar::unlinkArchive("$tmppath.gz");
			}				
		        catch (Exception $e) {
		                echo "Exception : " . $e;
				echo "\n$filename\t$base_dir/$year/$month/$day\n";
				exit;
		        }
			try {
				$filename = "$year$month$day" . "_old.tar";				
				$tmppath = "tmp/$filename";
				echo "\r$tmppath\r";
				if (file_exists($tmppath)) {
					unlink($tmppath);
				}
				if (file_exists("$tmppath.gz")) {
					unlink("$tmppath.gz");
				}
				$day_tar = new PharData($tmppath);
				$day_tar->buildFromDirectory("$base_dir/$year/$month/$day",'/\.js\.old/');
        		        $day_tar->compress(Phar::GZ);
				if (file_exists("$tmppath.gz")) {
					$client->putObject(array(
					    'Bucket'     => "uhcan",
					    'Key'        => "$base_upload_dir/$year/$month/$filename.gz",
					    'SourceFile' => "$tmppath.gz"
					));
					$client->waitUntilObjectExists(array(
					    'Bucket' => "uhcan",
					    'Key'    => "$base_upload_dir/$year/$month/$filename.gz"
					));
				   unset($day_tar);             
		                   unlink($tmppath);
                                   unlink("$tmppath.gz");          
	                           Phar::unlinkArchive($tmppath);
                                   Phar::unlinkArchive("$tmppath.gz");
				   //echo "\r$tmppath\r";
				}
				else {
					//echo "\rNo gzip file created: $tmppath\r";
				}
                                unset($day_tar);
			}				
		        catch (Exception $e) {
		                echo "Exception : " . $e;
				echo "\n$filename";
				exit;
		        }
		}
	}		
}
	
?>
