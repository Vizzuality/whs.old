
$(document).ready(function(){

  //FUNCTIONS FOR THE SEARCHBOX BEHAVIOUR 
  $('#searchText').focus(function() {
    this.value = '';
    $('this').animate({
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
    $('this').animate({
        width: '-=70'
      },200);
    $('.input_center').animate({
        width: '-=70'
      },200);
  });

});

