<?php

class Config {
    // DATABASE
	static $dbhost     = "127.0.0.1";
	static $dbuser     = "{DB_USER}";
	static $dbpass     = "{DB_PASS}";
	static $database   = "websnapit";

    static $cookie_file = '/var/www/hosts/www.websnapit.com/public/tmp/cookies.txt';

	static $logfile    = "/var/www/hosts/www.websnapit.com/public/websnap.log";

    // Queue filename (named pipe)
    // this file will be automatically created
	static $queue_dir = "/var/www/hosts/www.websnapit.com/public/tmp";

    // number of queue files an equal number of servers will be started.
    // each reading out 1 queue, this avoids having to use threads
    // the queue to be picked will be calculated.
	static $queue_number = 5;

    // The timeout from the webuser perspective
    // creation can still be in process or the creation
    // could even not have been started yet at all.
    static $timeout    = 15; // timeout in seconds

    // the (temporary) output directory for images.
    // upon succesful creation the image will be transfered to amazon S3 
    // and the file will be removed again 
    static $outputDir  = "/var/www/hosts/www.websnapit.com/public/out";
}
?>
