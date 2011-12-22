<?php

require dirname(__FILE__) . '/../config.php';
require dirname(__FILE__) . '/../lib/curl.php';
require dirname(__FILE__) . '/../lib/util.php';

class Websnap {

        // DB
        private $db; // db connection

        // Site
        private $siteTitle;
        private $siteDescription;
        private $siteKeyWords;

        function __construct()
        {
                $this->dbconnect();
        }

        /**
         *
         * Maak een connectie met de database
         *
         */
        private function dbconnect()
        {
                $this->db = new mysqli(Config::$dbhost, Config::$dbuser, Config::$dbpass,  Config::$database);
                if (mysqli_connect_errno()) {
                        Log::info(sprintf("Connect failed: %s\n", mysqli_connect_error()));
                        exit();
                }
        }

        private function sendJSON($response)
        {
                header("Content-type: text/json");
                echo json_encode($response);
                exit();
        }

        private function queueRequest($qid, $url)
        {

                // pick the queue..., TODO: find a more intelligent method to determine the queue number
                $nr = rand(1,Config::$queue_number);
                //Mode must be r+ or fopen will get stuck.

                Log::info("Opening pipe nr: $nr");
                $pipe = Util::open_pipe($nr, 'r+');
                fwrite($pipe, $url . "\n");
                fclose($pipe);
                Log::info("Closed pipe nr: $nr");

                // DB
                $api_key = "rhalff_test";

                $sql = "INSERT INTO requests SET api_key = '$api_key', url ='$url', qid = '$qid',status_code = 0;";
                return $this->db->query($sql);
        }

        public function showQueue()
        {

                $sql = "SELECT * FROM requests ORDER BY id DESC";
                if($result = $this->db->query($sql)) {
                        
                        while($obj = $result->fetch_object()){
                                var_export($obj);
                                echo "<hr/>";
                        }
                        $result->close();
                } 
                die();
        }

        public function doRequest($url) {

                $url = Util::sanitizeURL($url);

                if(false && !Util::validateURL($url)) {
                        $response = array(
                                        'errorCode'=>1008,
                                        'errorMsg'=>_('Invalid url') . $url
                                        );
                        $this->sendJSON($response);
                }

                $curl = new Curl($url);

                // real url after all redirects.
                $url = $curl->getRealUrl();

                $qid = Util::generateQid($url);

                $outfile = Config::$outputDir . "/$qid.png";

                if(!file_exists($outfile)) {

                        if(!$curl->isReachable()) {
                                $response = array(
                                                'errorCode'=>1009,
                                                'errorMsg'=>_('Site is unreachable please try again later')
                                                );
                                $this->sendJSON($response);
                        }
                }

                if($this->queueRequest($qid, $url)) {
                        Log::info("Queue $url");
                        $response = array(
                                        'items'=>array(
                                                array(
                                                        'title'=>$curl->getTitle(),
                                                        'qid'=>$qid
                                                     )
                                                )
                                        );

                        $this->sendJSON($response);
                } else {
                        $response = array(
                                        'errorCode'=>1009,
                                        'errorMsg'=>sprintf(_('Error: %s'), $this->db->error)
                                        );
                        $this->sendJSON($response);
                }
        }

        public function doQuery($qid) { 

                $outfile = Config::$outputDir . "/$qid.png";

                $s = 0;

                while(!file_exists($outfile) && ($s <= Config::$timeout)) {
                        $s++;
                        sleep(1); 
                }

                if(file_exists($outfile)) {

                        // success
                        $sql = "UPDATE requests SET status_code = 1 WHERE qid = '$qid'";

                        if (!$this->db->query($sql)) {
                                $response = array(
                                                'errorCode'=>1009,
                                                'errorMsg'=>sprintf(_('Error: %s'), $this->db->error)
                                                );
                                $this->sendJSON($response);
                        }  else { 

                                $img = "http://www.websnapit.com/out/$qid.png";
                                $response = array(
                                                'items'=>array(
                                                        array(
                                                                'title'=> '',
                                                                'src'=>$img
                                                             )
                                                        )
                                                );

                                $this->sendJSON($response);
                        }

                } else {
                        // aanmaken is blijkbaar mislukt.
                        if($s >= Config::$timeout) {
                                $response = array(
                                                'errorCode'=>1010,
                                                'errorMsg'=>sprintf(_('Time out: failed to create thumb within %d seconds'), Config::$timeout)
                                                );

                        } else {
                                $response = array(
                                                'errorCode'=>1010,
                                                'errorMsg'=>sprintf(_('Creation failed: %s (%d/%d)'), $outfile, $s, Config::$timeout)
                                                );
                        }
                        $this->sendJSON($response);

                }

        }

        function overview()
        {

                $sql = "SELECT * FROM requests";

                if ($result = $this->db->query($sql)) {
                        while($obj = $result->fetch_object()){

                                $file = "out/{$obj->qid}.png";
                                if(file_exists($file)) {
                                        echo $obj->url . "<hr/>";
                                        echo "<a href=\"view.php?qid={$obj->qid}\"><img width=\"350\" src=\"$file\"/></a><hr/>";
                                }
                        }
                }
                $result->close();
                unset($obj);
                unset($sql);
                die('list');
        }

        function view()
        {
                $qid = $_REQUEST['qid'];
                $sql = "SELECT * FROM requests WHERE qid='$qid'";

                if ($result = $this->db->query($sql)) {
                        $obj = $result->fetch_object();
                        $file = "out/{$obj->qid}.png";
                        if(file_exists($file)) {
                                echo $obj->url . "<hr/>";
                                echo "<img width=\"350\" src=\"$file\"/><hr/>";
                                echo '<textarea cols="50" rows="5">[img]http://www.websnapit.com/view?qid='.$qid.'[/img]</textarea>';
                                $url = htmlentities('<a href="http://www.websnapit.com/view?qid='.$qid.'"><img width="350" src="'.$file.'"/></a>');
                                echo '<textarea cols="50" rows="5">'.$url.'</textarea>';
                        }
                }
                $result->close();
                unset($obj);
                unset($sql);
        }

}
