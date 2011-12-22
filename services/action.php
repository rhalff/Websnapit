<?php

require dirname(__FILE__) . '/../config.php';
require dirname(__FILE__) . '/../lib/curl.php';
require dirname(__FILE__) . '/../lib/util.php';
require dirname(__FILE__) . '/../lib/websnap.php';

$action = $_REQUEST['action'];

$websnap = new Websnap();

switch($_REQUEST['action']) {

    case "w";
        $url = isset($_REQUEST['u']) ? $_REQUEST['u'] : false;
        Log::info("Direct request is $url");
        $websnap->doRequest($url);
    break;
    case "q";
        $qid = isset($_REQUEST['qid']) ? $_REQUEST['qid'] : false;
        $websnap->doQuery($qid);
    break;
    case "l";
        $websnap->showQueue();
    break;
    default:
        die('Unknown action');
    break;

}

?>
