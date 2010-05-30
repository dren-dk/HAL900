function log(str) {
    if (("console" in window) && ("firebug" in console)) {
	console.log(str);
    }	
}

function findPosX(obj) {
    var curleft = 0;
    if(obj.offsetParent)
        while(1) {
	    curleft += obj.offsetLeft;
	    if(!obj.offsetParent)
		break;
	    obj = obj.offsetParent;
        }
    else if(obj.x)
        curleft += obj.x;
    return curleft;
}

function findPosY(obj) {
    var curtop = 0;
    if(obj.offsetParent)
        while(1) {
	    curtop += obj.offsetTop;
	    if(!obj.offsetParent)
		break;
	    obj = obj.offsetParent;
        }
    else if(obj.y)
        curtop += obj.y;
    return curtop;
}

function insertAfter( referenceNode, newNode )
{
    referenceNode.parentNode.insertBefore( newNode, referenceNode.nextSibling );
}

function taBlur(id,type) {
    //log("Blur "+id);

    if (currentReq) {
	currentReq.abort();
	currentReq = null;
    }    

    if (timer) {
	clearTimeout(timer);
	timer = 0;
    }

    if (hitsDiv) {
	hitsDiv.parentNode.removeChild(hitsDiv);
	hitsDiv = null;
    }
}

var hitsDiv = null;
var hits;
var currentHit = -1;
var currentID = null;

function taSelect(index, done) {

    var oldHit = currentHit;
    currentHit = index;
    if (oldHit >= 0) {
	hitsDiv.childNodes[oldHit].setAttribute("class", "notselected");
    }
    hitsDiv.childNodes[currentHit].setAttribute("class", "selected");

    var input = document.getElementById(currentID);
    var output= document.getElementById(currentID+"-id");
    output.value = hits[currentHit].getAttribute("id");
    input.value = hits[currentHit].getAttribute("text");
}


var timer = 0;
function taKey(id,type,event) {
    log("Key "+id+" "+event.keyCode);

    if (hitsDiv != null && hits != null && hits.length > 0) {

	if (event.keyCode == 13 || event.keyCode == 9) {
	    if (currentHit >= 0 && currentHit < hits.length) {
		log("Picked index: "+currentHit);
		var input = document.getElementById(id);
		var output= document.getElementById(id+"-id");
		output.value = hits[currentHit].getAttribute("id");
		input.value = hits[currentHit].getAttribute("text");
	    }

	    taBlur(id);
	    return;
	}

	var oldHit = currentHit;
	if (event.keyCode == 40) {
	    currentHit++;
	    if (currentHit >= hits.length) {
		currentHit = 0;
	    }
	}
	if (event.keyCode == 38) {
	    currentHit--;
	    if (currentHit < 0) {
		currentHit = hits.length-1;
	    }
	}
	
	if (oldHit != currentHit) {
	    if (oldHit >= 0) {
		hitsDiv.childNodes[oldHit].setAttribute("class", "notselected");
	    }
	    hitsDiv.childNodes[currentHit].setAttribute("class", "selected");
	}
    }

    if (timer) {
	clearTimeout(timer);
	timer = 0;
    }

    timer = setTimeout("search(\""+id+"\",\""+type+"\")", 200);
}

var currentSearch = '';
var currentReq = null;
var currentInput = null;
function search(id,type) {
    currentID = id;
    //log("Search "+id);
    
    currentInput  = document.getElementById(id);
    var needle = currentInput.value;
    if (currentSearch != needle) {
	currentSearch = needle;
	//	log("Starting new search for "+id+" "+needle);

	if (currentReq) {
	    currentReq.abort();
	    currentReq = null;
	}

	currentReq = new XMLHttpRequest();
	currentReq.onreadystatechange=handleSearchResult;
	currentReq.open("GET", "/hal/admin/tool/search/"+type+"?needle="+escape(needle), true);
	currentReq.send(null);	
    }
}

function handleSearchResult() {
    if (currentReq.readyState == 4 && currentReq.status == 200) {

	if (hitsDiv) {
	    hitsDiv.parentNode.removeChild(hitsDiv);
	    hitsDiv = null;
	}

	hits = currentReq.responseXML.getElementsByTagName("hit");
	currentHit = -1;
	if (hits.length == 0) {
	    return;
	}

	hitsDiv = document.createElement("div");
	hitsDiv.setAttribute("class", "hits");
	
	for (var i=0; i < hits.length; i++) { 
	    var member = hits[i];
	    
	    var hd = document.createElement("div");
	    hd.setAttribute("class", "notselected");
	    hd.setAttribute("onmouseover", "taSelect("+i+", false)");
	    hd.setAttribute("onmouseclick",     "taSelect("+i+", true)");
	    hitsDiv.appendChild(hd);
	    hd.innerHTML = member.getAttribute("text");
	}

	insertAfter(currentInput, hitsDiv);	
    }
}
