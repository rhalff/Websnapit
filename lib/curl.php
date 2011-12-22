<?php

require_once dirname(__FILE__) . '/log.php';

class Curl {

        private $data;
        private $header;
        private $retries = 0;
        private $url;

        function __construct($url)
        {
            $this->url = $url;
            $this->init_data();
        }

        function init_data()
        {

                if(!$this->data) {
                        Log::info("Curl::init_data, {$this->url}");
                        $curl = curl_init($this->url);

                        //curl_setopt($curl, CURLOPT_URL, $this->url);
                        curl_setopt($curl, CURLOPT_HEADER, 1);
                        $ua = isset($_SERVER['HTTP_USER_AGENT']) ? $_SERVER['HTTP_USER_AGENT'] : "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.4; nl; rv:1.9.0.10) Gecko/2009042315 Firefox/3.0.10";

                        curl_setopt($curl, CURLOPT_ENCODING, "");
                        curl_setopt($curl, CURLOPT_USERAGENT, $ua);
                        curl_setopt($curl, CURLOPT_FOLLOWLOCATION, 1);
                        curl_setopt($curl, CURLOPT_RETURNTRANSFER, 1);
                        curl_setopt($curl, CURLOPT_AUTOREFERER, 1); // set referer on redirect 
                        curl_setopt($curl, CURLOPT_CONNECTTIMEOUT, 10); // timeout on connect
                        curl_setopt($curl, CURLOPT_TIMEOUT, 30); // timeout on response
                        curl_setopt($curl, CURLOPT_MAXREDIRS, 10); 

                        curl_setopt($curl, CURLOPT_COOKIEJAR, Config::$cookie_file);
                        curl_setopt($curl, CURLOPT_COOKIEFILE, Config::$cookie_file);
                        // bepaal uiteindelijke url, na de redirect, test met b.v. markplaats.nl die redirect in iedergeval 2 keer.

                        if(!$this->data = curl_exec($curl)) {
                                $err     = curl_errno($curl); 
                                $errmsg  = curl_error($curl); 
                                Log::info("curl_exec failed for {$this->url}: $errmsg ($err)");
                        } else {

                                $this->header = curl_getinfo($curl);
                                Log::info("curl: site is available {$this->url}");
                                Log::info("curl: real url is {$this->header['url']}");
                        }

                        curl_close($curl);
/*
                        if($header['url'] != self::realUrl($url) && self::$retries <= 2) {
                            // probeer het nog is, niet meer als 2 keer.
                            Log::info("Curl::init_data, $url, try again...");
                            self::reset();
                            self::$retries++;
                            self::init_data($header['url']);
                        }
*/

                }
        }

        public function reset()
        {
               $this->data = null;
        }

        /**
         *
         * Controleerd of the url bereikbaar is via curl
         * En haalt de basisgegevens van de site op.
         *
         * Tevens wordt gecontroleerd of er redirects zijn en de url 
         * wordt daar op aangepast.
         *
         */
        public function isReachable()
        {

                if ($this->data) {
                        // eventueel titel enzo uit de site vissen en doorgeven in de json.
                        return true;
                } else {
                        return false;
                }       
        }      

        /**
         *
         * Get final url after redirect 
         *
         */
        public function getRealUrl()
        {
                return $this->header['url'];
        }

        /**
         *
         * Geeft de titel terug van een bepaalde website
         *
         */ 
        public function getTitle()
        {
                return Util::getTagByName('title', $this->data);
        }

        /**
         *
         * Geeft de meta description terug van een bepaalde website
         *
         */ 
        public function getDescription()
        {
                return Util::getMetaByName('description', $this->data);
        }

        /**
         *
         * Geeft de meta keywords terug van een bepaalde website
         *
         */ 
        public function getKeywords($url)
        {
                return Util::getMetaByName('keywords', $this->data);
        }

}
