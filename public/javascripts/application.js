
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

