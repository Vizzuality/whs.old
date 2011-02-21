function updateCredits() {
  // Update the photo credits
  var selectedImageIndex = $("div.nivo-controlNav a.active").attr("rel");
  var link = $('<a/>', {href: imageInfo[selectedImageIndex]['author_url']}).text(imageInfo[selectedImageIndex]['author']);
  $("#photo_credits").html('').append("Photo by ").append(link);
  // In slider mode, show the photo credits
  if (!$("div#img_thumb").is(":visible")) {
      $('#photo_credits').fadeIn("fast");
  }
}

$(window).load(function() {
  $('#slider').nivoSlider({
    effect: "fade",
    directionNav: false,
    controlNav: true,
    beforeChange: function() {$('#photo_credits').fadeOut("fast")},
    afterChange: updateCredits,
    afterLoad: updateCredits
  });
});

$(document).ready( function(){

  $("a#zoomin").click(function(ev) {
      ev.stopPropagation();
      ev.preventDefault();
      map.setZoom(map.getZoom()+1);
  });

  $("a#zoomout").click(function(ev) {
      ev.stopPropagation();
      ev.preventDefault();
      map.setZoom(map.getZoom()-1);
  });


  $("div.map_container").mouseover(function() {
    $("div#darken").show();
    $("a#show_link").show();
  });

  $("div.map_container").mouseout(function() {
    $("div#darken").hide();
    $("a#show_link").hide();
  });

  $("div.map_container div#darken a").click(function(ev) {
    ev.stopPropagation();
    ev.preventDefault();

    if ($("div#img_thumb").is(":visible")) {
      // Swap big area to images
        $("#slider").fadeIn();
        $("#photo_credits").fadeIn();
        $("div#img_thumb").hide();
        $("a#show_link").html("Show map");
    } else {
      // Swap big area to map
        $("div#big_map_container").css("visibility","visible");
        $("#slider").fadeOut();
        $("#photo_credits").fadeOut();
        $("div#img_thumb").show();
        $("a#show_link").html("Show images");
    }
  });

  // Map customization
  var myOptions = {
    zoom: 8,
    disableDefaultUI: true,
    center: new google.maps.LatLng(feature['the_geom']['y'], feature['the_geom']['x']),
    mapTypeId: google.maps.MapTypeId.TERRAIN
  };
  var map = new google.maps.Map(document.getElementById("big_map"), myOptions);

  // Adding the marker
  var latlng = new google.maps.LatLng(feature['the_geom']['y'], feature['the_geom']['x']);
  var marker = new google.maps.Marker({
    position: latlng,
    map: map,
    title: feature['title'],
    icon: "/images/explore/marker_" + feature['meta']['type'] + ".png"
  });

  $.each(nearest_places, function(index, place){
    marker = new google.maps.Marker({
      position: new google.maps.LatLng(place['feature']['lat'], place['feature']['lon']),
      map: map,
      title: place['feature']['title'],
      icon: "/images/marker_" + place['feature']['meta']['type'] + "_mini.png"
    });
    google.maps.event.addListener(marker, "click", function() { window.location = "/features/" + place['feature']['id'] + "%>" });
  });

});
