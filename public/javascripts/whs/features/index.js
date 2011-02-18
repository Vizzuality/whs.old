var
    form,
    search_url,
    map,
    marker,
    latlng,
    features,
    markers = [],
    search_params = {},
    showSearchLabel = function(){
      var q = $('#q');
      if (!q.val() || q.val() == '') {
        q.prev('label').fadeIn(200);
      };
    },
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
      centerOnMarkers();
    },
    clearMarkers = function(){
      $.each(markers, function(index, marker){
        marker.setMap(null);
      });
      markers = [];
    },
    centerOnMarkers = function(){

      var lats  = $.map(markers, function(marker, index){ return marker.position.lat() }),
          longs = $.map(markers, function(marker, index){ return marker.position.lng() }),
          south_west = new google.maps.LatLng(Array.min(lats), Array.min(longs)),
          north_east = new google.maps.LatLng(Array.max(lats), Array.max(longs)),
          markers_bounds = new google.maps.LatLngBounds(south_west, north_east);

      map.fitBounds(markers_bounds);
    },
    getResults = function(){
      $.get(search_url, search_params, function(html){
        $('#results').html(html);
        addMarkers();
      });
    },
    urlParam = function(url, name){
      var results = new RegExp('[\\?&]' + name + '=([^&#]*)').exec(url);
      return results[1];
    };

  $(document).ready( function(){
    form       = $('#ajaxSearch'),
    search_url = form.attr('action');

    showSearchLabel();

    form.submit(function(ev){
      ev.preventDefault();
      $('#searchText').val('');
      search_params['q'] = $('#q').val();
      getResults();
    });

    $('#q').focus(function(){
      $(this).prev('label').fadeOut(200);
    })
    .blur(function(){
      showSearchLabel();
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
      search_params['q'] = $('#q').val();
      search_params['criteria'] = urlParam($(this).attr('href'), 'criteria');
      getResults();
    });

    $("a.type_selector").click(function(ev) {
      search_params['q'] = $('#q').val();
      search_params['type'] = urlParam($(this).attr('href'), 'type');
      getResults();
    });

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

Array.max = function( array ){
    return Math.max.apply( Math, array );
};
Array.min = function( array ){
    return Math.min.apply( Math, array );
};
