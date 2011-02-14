
$(document).ready(function(){

  //FUNCTIONS FOR THE SEARCHBOX BEHAVIOUR 
  $('#searchText').focus(function() {
    this.value = '';
    $('#searchText').animate({
        width: '+=70'
      },200);
    $('.input_center').animate({
        width: '+=70'
      },200);
  });
  $('#searchText').focusout(function() {
    if(this.value == ''){
      this.value = 'Search...';
    }
    $('#searchText').animate({
        width: '-=70'
      },200);
    $('.input_center').animate({
        width: '-=70'
      },200);
  });

  //FUNCTION FOR THE MOSAIC's ELEMENTS
  $('.mosaic_element_div').hover(function() {
    $(this).children(".mosaic_label").show();
   },function(){
    $(this).children(".mosaic_label").hide();
  });   

});

	//FUNCTION FOR THE IMAGE SLIDESHOW ON FEATURES PAGE
	
	function changeOpac(opacity, id) {
		var object = document.getElementById(id).style; 
		object.opacity = (opacity / 100);
		object.MozOpacity = (opacity / 100);
		object.KhtmlOpacity = (opacity / 100);
		object.filter = "alpha(opacity=" + opacity + ")";
	}

	function blendimage(divid, imageid, imagefile, millisec, alt, total, workn, linkn) {
		var speed = Math.round(millisec / 100);
		var timer = 0;
		document.getElementById(divid).style.backgroundImage = "url(" + document.getElementById(imageid).src + ")";
		document.getElementById(divid).style.backgroundRepeat = "no-repeat";		
		changeOpac(0, imageid);
		document.getElementById(imageid).src = imagefile;
		for(i = 0; i <= 100; i++) {
			setTimeout("changeOpac(" + i + ",'" + imageid + "')",(timer * speed));
			timer++;
		}
		substr = imageid.substring(10,11);
		for (i=1; i<=total; i++) {
			link = "workLink" + workn + i;
			document.getElementById(link).className = "";
		}
		document.getElementById("workLink"+workn+linkn).className = "current";
	}