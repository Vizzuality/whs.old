var map,
    marker,
    latlng,
    features,
    markers = [],
    addMarkers = function(){
      clearMarkers();
      $.each(features, function(index, feature){
        latlng = new google.maps.LatLng(feature['lat'], feature['lon']);

        marker = new google.maps.Marker({
          position: latlng,
          map: map,
          title: feature['title'],
          icon: "/images/explore/marker_" + feature['type'] + ".png"
        });

        markers.push(marker);

        google.maps.event.addListener(marker, "click", function() {window.location = "/features/" + feature['id']});
      });
    },
    clearMarkers = function(){
      $.each(markers, function(index, marker){
        marker.setMap(null);
      });
    };


  $(document).ready( function(){
    var form = $('#ajaxSearch');

    form.submit(function(evt){
      evt.preventDefault();
      $.get(form.attr('action'), form.serialize(), function(html){
        $('#results').html(html);
        addMarkers()
      });
    });

    $('#q').focus(function(){
      $(this).prev('label').fadeOut(200);
    })
    .blur(function(){
      var q = $(this).val();
      if (!q || q == '') {
        $(this).prev('label').fadeIn(200);
      };
    });

    $("a.type_selector").click(function(ev) {
      ev.stopPropagation();
      ev.preventDefault();
      var classes = $(this).attr('class').split(' ');
      $("a.type_selector").removeClass('selected');
      if ($.inArray('selected', classes) < 0) {
        $(this).addClass('selected');
      };
    });

    $("a#all_selector").click(function(ev){
      $('#type').val('');
    });
    $("a#natural_selector").click(function(ev){
      $('#type').val('');
      if ($(this).hasClass('selected')) {
        $('#type').val('natural');
      };
    });

    $("a#cultural_selector").click(function(ev){
      $('#type').val('');
      if ($(this).hasClass('selected')) {
        $('#type').val('cultural');
      };
    });

    $("a.type_selector").click(function(ev) {
      form.submit();
    });


    $("a#mosaic_selector").click(function(ev) {
      ev.stopPropagation();
      ev.preventDefault();
      $("a#mosaic_selector").addClass("selected");
      $("a#list_selector").removeClass("selected");

      $("div#explore div.middle div#list").hide();
      $("div#explore div.middle div#mosaic").show();
    });


    $("a#list_selector").click(function(ev) {
      ev.stopPropagation();
      ev.preventDefault();
      $("a#mosaic_selector").removeClass("selected");
      $("a#list_selector").addClass("selected");

      $("div#explore div.middle div#list").show();
      $("div#explore div.middle div#mosaic").hide();
    });


    $("a#criteria_label").click(function(ev) {
      ev.stopPropagation();
      ev.preventDefault();
      if ($("div#criteria_select ul").is(":visible")) {
        $("div#criteria_select span").css("backgroundPosition","-2px 0");
      } else {
        $("div#criteria_select span").css("backgroundPosition","-2px -24px");
      }
      $("div#criteria_select ul").toggle();
    });

    $("div#criteria_select ul a").click(function(ev) {
      ev.stopPropagation();
      ev.preventDefault();
      $("div#criteria_select span").css("backgroundPosition","-2px 0");
      $("div#criteria_select ul").toggle();
      $("a#criteria_label").text($(this).text());
    });

    $('a.criteria').click(function(ev){
      ev.stopPropagation();
      ev.preventDefault();
      $('input#criteria').val($(this).attr('id'));
      form.submit();
    })


    $("div#map").mouseover(function() {
      $("h1").hide();
    });

    $("div#map").mouseout(function() {
      $("h1").show();
    });

    var myOptions = {
      zoom: 2,
      disableDefaultUI: true,
      center: new google.maps.LatLng(40,10),
      mapTypeId: google.maps.MapTypeId.TERRAIN
    };

    map = new google.maps.Map(document.getElementById("map"), myOptions);

    addMarkers();
  });

