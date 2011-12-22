<html>
<head>
<title>Websnap it! Take screenshots of any website.</title>
<link rel="stylesheet" href="style.css" type="text/css" media="screen" />
<script type="text/javascript" src="js/jquery-1.3.2.min.js"></script>
<script type="text/javascript">

$(document).ready(function() {

    $('#w_f').submit(function() {

        var url = $('input[name=url]').val();
        var ne = $("<div class=\"thumb'\"></div>");
        $('#screenshots').append(ne);
        loadURL(url, ne);

        return false;
    });

});
    var debug = function(msg) {
        if(typeof console.log != 'undefined') {
            console.log(msg);
        } else {
            alert(msg);
        }
    }

    function loadURL(url, targetEl)
    {
        $("#loader").removeClass('loaded');
        $("#loader").addClass('loading');

        var h = "http://www.websnapit.com";
        $.getJSON( h + "/services/action.php", { action: 'w', u: url },
        function(data, textStatus){
          if(data.errorMsg) {
                debug(data.errorMsg);
                return false;
          } else {
            $.each(data.items, function(i,item) {
              $.getJSON( h + "/services/action.php?action=q&qid="+item.qid,
                function(dat, textStatus) {
                  $("#loader").removeClass('loading');
                  if(textStatus == 'success') {
                    $("#loader").addClass('loaded');
                    if(dat.errorMsg) {
                     debug(dat.errorMsg);
                     return false;
                    } else {
                     $.each(dat.items, function(i,item){
                        $(targetEl).html($("<img width=\"120\"/>").attr("src", item.src).attr("title", item.title));
                        if (i == 3) return false;
                     });
                   }

                  } else {
                    $("#loader").addClass('loaderror');
                  }
              });
            });
         }
        });
    }

function stressTest()
{
        for(var i=0; i<20; i++) { 
                var ne = $("<div class=\"thumb'\" style=\"width: 50px; height: 50px, border: 1px solid red; float: left; margin: 1em;\"></div>");
                $('#screenshots').append(ne);
                loadURL("http://www.websnapit.com/stressTestPage?i="+i, ne);
        }

}

</script> 
</head>
<body>
<div id="main">
  <form id="w_f" action="w.php">
   <fieldset>
      <label for="url">URL:</label>
      <input type="text" name="url"/>
      <input type="submit" id="w_s" value="Websnap it!"/> 
   </fieldset>
  </form>
  <div id="loader"></div>
  <div id="screenshots"></div>
</div> 
</body>
</html>
