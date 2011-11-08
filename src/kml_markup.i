// vim: set ts=3 sts=3 sw=3 ai sr et:

func kml_color(r, g, b, a) {
/* DOCUMENT kml_color(r, g, b, a)
   Given a color defined by r, g, b, and optionally a (all numbers), this will
   return the properly formatted colorcode per the KML spec.

   If alpha is omitted, it defaults to fully opaque (255).
*/
   default, a, array(short(255), dimsof(r));
   if(anyof(0 < r & r < 1))
      r = short(r * 255);
   if(anyof(0 < g & g < 1))
      g = short(g * 255);
   if(anyof(0 < b & b < 1))
      b = short(b * 255);
   if(anyof(0 < a & a < 1))
      a = short(a * 255);
   return swrite(format="%02x%02x%02x%02x", short(a), short(b), short(g), short(r));
}

local kml_Document, kml_Style, kml_BalloonStyle, kml_IconStyle, kml_LineStyle,
   kml_ListStyle, kml_PolyStyle, kml_Folder, kml_Placemark, kml_NetworkLink,
   kml_Feature, kml_Snippet, kml_MultiGeometry, kml_LineString, kml_Point,
   kml_coordinates, kml_Link, kml_Region, kml_LatLonBox, kml_Icon,
   kml_GroundOverlay;
/* DOCUMENT kml_Document kml_Style kml_BalloonStyle kml_IconStyle kml_LineStyle
   kml_ListStyle kml_PolyStyle kml_Folder kml_Placemark kml_NetworkLink
   kml_Feature kml_Snippet kml_MultiGeometry kml_LineString kml_Point
   kml_coordinates kml_Link kml_Region kml_LatLonBox kml_Icon kml_GroundOverlay

   The above functions each correspond directly to the KML tags they are named
   for. These functions are constructed such that:

      - Many of them take one or more positional arguments, which should be
        strings or arrays of strings. Such strings will be wrapped within the
        tag the function is named for.

      - Many of them take one or more named optional arguments, which should
        generally be strings. These arguments are either attributes on the tag
        (such as id=) or are simple sub-tags that are often/always associated
        with the tag.

   As an example, consider kml_Link, which has the signature:

      func kml_Link(items,..,id=,href=)

   In the KML spec, the "Link" tag has one attribute, "id". It commonly
   contains the tag "href". It also may contain other tags, but they'd have to
   be passed in as string data as one of the ITEMS arguments.

   SEE ALSO: kml_element kml_color
*/

func kml_Document(items, .., id=, name=, visibility=, Open=, description=,
styleUrl=) {
   while(more_args())
      grow, items, next_arg();

   Document = kml_Feature("Document", items, id=id, description=description,
      name=name, visibility=visibility, Open=Open, styleUrl=styleUrl);

   return swrite(format="\
<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<kml xmlns=\"http://earth.google.com/kml/2.2\">\n\
%s\n\
</kml>", Document);
}

func kml_Style(items, .., id=) {
   while(more_args())
      grow, items, next_arg();
   return kml_element("Style", items, id=id);
}

func kml_BalloonStyle(void, id=, bgColor=, textColor=, text=, displayMode=) {
   elems = [];
   grow, elems, kml_element("bgColor", bgColor);
   grow, elems, kml_element("textColor", textColor);
   grow, elems, kml_element("text", text);
   grow, elems, kml_element("displayMode", displayMode);
   return kml_element("BalloonStyle", elems, id=id);
}

func kml_IconStyle(void, id=, color=, colorMode=, scale=, heading=, href=, x=,
y=, xunits=, yunits=) {
   elems = [];
   grow, elems, kml_element("color", color);
   grow, elems, kml_element("colorMode", colorMode);
   grow, elems, kml_element("scale", scale);
   grow, elems, kml_element("heading", heading);
   grow, elems, kml_element("Icon", kml_element("href", href));

   hotSpot = "";
   if(!is_void(x))
      hotSpot += swrite(format=" x=\"%s\"", x);
   if(!is_void(y))
      hotSpot += swrite(format=" y=\"%s\"", y);
   if(!is_void(xunits))
      hotSpot += swrite(format=" xunits=\"%s\"", xunits);
   if(!is_void(yunits))
      hotSpot += swrite(format=" yunits=\"%s\"", yunits);
   if(strlen(hotSpot) > 0)
      grow, elems, swrite(format="<hotSpot%s />\n", hotSpot);

   return kml_element("IconStyle", elems, id=id);
}

func kml_LineStyle(void, id=, color=, colorMode=, width=) {
   elems = [];
   grow, elems, kml_element("color", color);
   grow, elems, kml_element("colorMode", colorMode);
   grow, elems, kml_element("width", width);
   return kml_element("LineStyle", elems, id=id);
}

func kml_ListStyle(void, id=, listItemType=, bgColor=, state=, href=) {
   elems = [];
   grow, elems, kml_element("listItemType", listItemType);
   grow, elems, kml_element("bgColor", bgColor);

   iconelems = [];
   grow, iconelems, kml_element("state", state);
   grow, iconelems, kml_element("href", href);
   grow, elems, kml_element("ItemIcon", iconelems);

   return kml_element("ListStyle", elems, id=id);
}

func kml_PolyStyle(void, id=, color=, colorMode=, fill=, outline=) {
   elems = [];
   grow, elems, kml_element("color", color);
   grow, elems, kml_element("colorMode", colorMode);
   grow, elems, kml_element("fill", fill);
   grow, elems, kml_element("outline", outline);
   return kml_element("PolyStyle", elems, id=id);
}

func kml_Folder(items, .., id=, name=, visibility=, Open=, description=,
styleUrl=) {
   while(more_args())
      grow, items, next_arg();
   return kml_Feature("Folder", items, id=id, description=description,
      name=name, visibility=visibility, Open=Open, styleUrl=styleUrl);
}

func kml_Placemark(items, .., id=, name=, description=, visibility=, Open=,
styleUrl=) {
   while(more_args())
      grow, items, next_arg();
   return kml_Feature("Placemark", items, id=id, description=description,
      name=name, visibility=visibility, Open=Open, styleUrl=styleUrl);
}

func kml_NetworkLink(items, .., id=, name=, description=, visibility=, Open=,
styleUrl=) {
   while(more_args())
      grow, items, next_arg();
   return kml_Feature("NetworkLink", items, id=id, description=description,
      name=name, visibility=visibility, Open=Open, styleUrl=styleUrl);
}

func kml_Feature(type, items, .., id=, name=, visibility=, Open=, description=,
styleUrl=) {
   while(more_args())
      grow, items, next_arg();
   elems = [];
   grow, elems, kml_element("name", name);
   grow, elems, kml_element("visibility", visibility);
   grow, elems, kml_element("open", Open);
   grow, elems, kml_element("description", description);
   grow, elems, kml_element("styleUrl", styleUrl);
   return kml_element(type, elems, items, id=id);
}

func kml_Snippet(text, maxLines=) {
   return kml_element("Snippet", text, maxLines=maxLines);
}

func kml_MultiGeometry(items, .., id=) {
   while(more_args())
      grow, items, next_arg();
   return kml_element("MultiGeometry", items, id=id);
}

func kml_LineString(lon, lat, alt, id=, extrude=, tessellate=, altitudeMode=) {
   elems = [];
   grow, elems, kml_element("extrude", extrude);
   grow, elems, kml_element("tessellate", tessellate);
   grow, elems, kml_element("altitudeMode", altitudeMode);
   grow, elems, kml_coordinates(lon, lat, alt);
   return kml_element("LineString", elems, id=id);
}

func kml_Point(lon, lat, alt, id=, extrude=, altitudeMode=) {
   elems = [];
   grow, elems, kml_element("extrude", extrude);
   grow, elems, kml_element("altitudeMode", altitudeMode);
   grow, elems, kml_coordinates(lon, lat, alt);
   return kml_element("Point", elems, id=id);
}

func kml_coordinates(lon, lat, alt) {
   if(is_void(alt))
      coordinates = swrite(format="%.5f,%.5f", lon, lat);
   else
      coordinates = swrite(format="%.5f,%.5f,%.2f", lon, lat, alt);
   return kml_element("coordinates", strwrap(strjoin(coordinates, " ")));
}

func kml_Link(items, .., id=, href=) {
   while(more_args())
      grow, items, next_arg();
   return kml_element("Link", kml_element("href", href), items, id=id);
}

func kml_Region(items, .., id=, north=, south=, east=, west=, minAltitude=,
maxAltitude=, altitudeMode=, minLodPixels=, maxLodPixels=, minFadeExtent=,
maxFadeExtent=) {
   elems = [];
   grow, elems, kml_element("north", north);
   grow, elems, kml_element("south", south);
   grow, elems, kml_element("east", east);
   grow, elems, kml_element("west", west);
   grow, elems, kml_element("minAltitude", minAltitude);
   grow, elems, kml_element("maxAltitude", maxAltitude);
   grow, elems, kml_element("altitudeMode", altitudeMode);
   LatLonAltBox = kml_element("LatLonAltBox", elems);

   elems = [];
   grow, elems, kml_element("minLodPixels", minLodPixels);
   grow, elems, kml_element("maxLodPixels", maxLodPixels);
   grow, elems, kml_element("minFadeExtent", minFadeExtent);
   grow, elems, kml_element("maxFadeExtent", maxFadeExtent);
   Lod = kml_element("Lod", elems);

   return kml_element("Region", LatLonAltBox, Lod, id=id);
}

func kml_LatLonBox(items, .., north=, south=, east=, west=, rotation=) {
   while(more_args())
      grow, items, next_arg();
   grow, items, kml_element("north", north);
   grow, items, kml_element("south", south);
   grow, items, kml_element("east", east);
   grow, items, kml_element("west", west);
   grow, items, kml_element("rotation", rotation);
   return kml_element("LatLonBox", items);
}

func kml_Icon(void, href=) {
   return kml_element("Icon", kml_element("href", href));
}

func kml_GroundOverlay(items, .., id=, name=, visibility=, Open=, description=, styleUrl=, north=, south=, east=, west=, rotation=, drawOrder=, color=, href=) {
   while(more_args())
      grow, items, next_arg();

   grow, items, kml_LatLonBox(north=north, south=south, east=east, west=west,
      rotation=rotation);
   grow, items, kml_element("drawOrder", drawOrder);
   grow, items, kml_element("color", color);
   grow, items, kml_Icon(href=href);

   return kml_Feature("GroundOverlay", items, id=id, description=description,
      name=name, visibility=visibility, Open=Open, styleUrl=styleUrl);
}

func kml_element(args) {
/* DOCUMENT kml_element(name, items, items, ..., attrib=, attrib=, ...)
   Generates the code for a generic KML tag. NAME is the tag's name, ITEMS
   should go inside the element, and ATTRIB= can be any arbitrary attribute
   name. For example:

      > write, kml_element("foo","bar",a="b",c=42)
       <foo a="b" c=42>bar</foo>

   Some particulars:

      - NAME must be a scalar string.
      - ITEMS is normally a string or array of strings.
      - Multiple ITEMS are merged into a single array.
      - If only one ITEMS is present and it is scalar, it may optionally be
        numerical. Floating point values will receive at most 6 decimal places.
      - ATTRIB names can be anything valid as a Yorick keyword argument. The
        value should be a scalar string or scalar number. (Scalar numbers are
        handled as for ITEMS.)
      - An ATTRIB can also have a void value, in which case it will be ignored.

   If you need to use an attribute that isn't a valid Yorick keyword argument
   name, you can fake it by passing it through as part of NAME, like so:

      > write, kml_element("example 1attrib=42", "foo")
*/
   name = args(1);
   if(!is_string(name))
      error, "First argument must be a string (the tag name)";

   items = [];
   for(i = 2; i <= args(0); i++)
      grow, items, args(i);
   if(is_void(items)) items = string(0);

   attribs = "";
   keys = args(-);
   for(i = 1; i <= numberof(keys); i++) {
      key = keys(i);
      val = args(key);
      // Ignore void keywords
      if(is_void(val))
         continue;
      if(!is_string(val) && !is_integer(val) && !is_real(val))
         val = swrite(val);
      if(is_string(val)) {
         attribs += swrite(format=" %s=\"%s\"", key, val);
      } else if(is_integer(val)) {
         attribs += swrite(format=" %s=%d", key, val);
      } else {
         len = 0;
         while(len < 6 && long(val * 10 ^ len)/(10. ^ len) != val)
            len++;
         fmt = swrite(format=" %%s=%%.%df", len);
         attribs += swrite(format=fmt, key, val);
      }
   }

   if(numberof(items) == 1 && !is_string(items(1))) {
      items = items(1);
      if(is_integer(items))
         items = swrite(format="%d", items);
      if(is_real(items)) {
         len = 0;
         while(len < 6 && long(items * 10 ^ len)/(10. ^ len) != items)
            len++;
         fmt = swrite(format="%%.%df", len);
         items = swrite(format=fmt, items);
      }
      if(!is_string(items))
         items = swrite(items);
   }

   single = numberof(items) == 1;

   if(single)
      single = strlen(name) * 2 + strlen(attribs) + strlen(items(1)) <= 66;

   if(single)
      single = !strmatch(items(1), "\n");

   if(single)
      single = (strpart(items(1), 1:1) != "<");

   if(single) {
      items = items(1);
      fmt = "<%s%s>%s</%s>";
   } else {
      items = strjoin(unref(items), "\n");
      if(strlen(items) < 1000)
         items = strindent(unref(items), "  ");
      fmt = "<%s%s>\n%s\n</%s>";
   }

   return swrite(format=fmt, name, attribs, items, name);
}
wrap_args, kml_element;
