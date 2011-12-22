<?php

require_once dirname(__FILE__) . '/../config.php';

class Util {
        /**
         *
         * De url + de dag.
         *
         * Dit zorgt dus voor een uniek shot per dag. 
         *
         * TODO: Echter mocht de afbeelding niet voldoen, dan moet een nieuwe 
         * gemaakt kunnen worden zonder de andere weg te gooien.
         *
         */
        static function generateQid($url)
        {
                $qid = md5($url . date('Ymd'));
                return $qid;
        }

        static function getTagByName($tag, $data)
        {       
                $content = '';
                preg_match('/<'.$tag.'>\s*(.*)\s*<\/'.$tag.'>/i', $data, $matches);
                if(isset($matches[1]) && !empty($matches[1])) {
                        $content = $matches[1];
                }
                return $content;
        }

        static function getMetaByName($name, $data)
        {       
                $content = '';
                $reg = '/<meta\s+name="'.$name.'"\s+content="(.*)"\s*>/i';
                preg_match($reg, $data, $matches);
                if(isset($matches[1]) && !empty($matches[1])) {
                        $content = $matches[1];
                } else {
                        preg_match('/<meta\s+content="(.*)"\s+name="'.$name.'"\s*>/i', $data, $matches);
                        if(isset($matches[1]) && !empty($matches[1])) {
                                $content = $matches[1];
                        }
                }
                return $content;
        }

        static function open_pipe($nr, $mode = 'r')
        {

                self::init_pipes();

                // pick the queue..., TODO: find a more intelligent method to determine the queue number
                $queue_file = Config::$queue_dir . "/websnap_queue_$nr";

                $pipe = fopen($queue_file, $mode);
                return $pipe;
        }

        static function init_pipes()
        {

                for($i=1; $i<=Config::$queue_number; $i++) {
                        $queue_file = Config::$queue_dir . "/websnap_queue_$i";
                        if(!file_exists($queue_file)) {
                                posix_mkfifo($queue_file, 0644);
                        }
                }

        }

        static function sanitizeURL($url)
        {
                if(substr($url, 0, 7) != 'http://' && substr($url, 0, 8) != 'https://')
                {
                        $url = "http://$url";
                }

                return $url;
        }

        /**
         *
         * Controleer of dit een valide url is.
         * Dit is alles behalve bullet proof maar vangt de meeste vergissingen op
         *
         */
        static function validateURL($url)
        {
                return eregi("^(http://)((([a-z0-9-]+(.[a-z0-9-]+)*(.[a-z]{2,3}))|(([0-9]{1,3}.){3}([0-9]{1,3})))((/|?)[a-z0-9~#%&'_+=:?.-]*)*)$", $url);
        }

}

?>
