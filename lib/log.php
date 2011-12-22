<?php

require_once dirname(__FILE__) . '/../config.php';

class Log {

    static $id = null;

	static function info($message)
	{
		self::_log($message);
	}

	static function _log($message)
	{
        if(self::$id === null) { self::$id = substr(md5(time()), 0, 7); }
		$fp = fopen(Config::$logfile, 'a+');
		fputs($fp, self::$id .": $message\n");
		fclose($fp);
	}	

}
