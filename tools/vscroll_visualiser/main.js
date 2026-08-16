const bgScrollValEl = document.getElementById("bgScrollVal");
const backgroundEl = document.getElementById("backgroundVis");
const bgOutlineEl = document.getElementById("bgOutline");
const bgShadow1El = document.getElementById("bgShadow1");
const bgShadow2El = document.getElementById("bgShadow2");

const tmScrollValEl = document.getElementById("tmScrollVal");
const tilemapEl = document.getElementById("tilemapVis");
const tilemapRows = tilemapEl.querySelectorAll(":scope > .row");
const tmOutline1El = document.getElementById("tmOutline1");
const tmOutline2El = document.getElementById("tmOutline2");
const tmShadow1El = document.getElementById("tmShadow1");
const tmShadow2El = document.getElementById("tmShadow2");

const upButton = document.getElementById("upButton");
const downButton = document.getElementById("downButton");
const scrollIntervalBox = document.getElementById("scrollIntervalBox");

const bgHeight = 896;
const maxBgScrollOffset = bgHeight - 192;

let bgScrollOffset = 0;
let tmScrollOffset = 0;
let scrollInterval;

// set initial viewport rows
for (let i = 0; i < 24; i++) setTilemapVisRow(i, i);

// fetch scroll interval from form
updateScrollInterval();

// update visualisation
updateOffsetLabels();
updateTilemapOverlays();
updateBackgroundOverlays();

scrollIntervalBox.addEventListener("change", updateScrollInterval);
upButton.addEventListener("click", scrollUp);
downButton.addEventListener("click", scrollDown);

function updateScrollInterval() {
    const val = parseInt(scrollIntervalBox.value);
    if (!isNaN(val) && val > 0 && val <= 8)
        scrollInterval = val;
    else
        scrollIntervalBox.value = scrollInterval;
}

function scrollUp() {
    // ensure we're not scrolling beyond the background..
    const scrollDelta = bgScrollOffset < scrollInterval
        ? bgScrollOffset
        : scrollInterval;
    if (scrollDelta === 0) 
        return;
    
    // scroll the viewport up
    bgScrollOffset -= scrollDelta;
    tmScrollOffset = mod((tmScrollOffset - scrollDelta), 224);

    // redraw the last row on the viewport
    const lastTmRowOnViewport = tmScrollOffset >> 3;
    const lastBgRowOnViewport = bgScrollOffset >> 3;
    setTilemapVisRow(lastTmRowOnViewport, lastBgRowOnViewport);    

    // update info panel
    tmScrollValEl.innerText = tmScrollOffset;

    updateOffsetLabels();
    updateBackgroundOverlays();
    updateTilemapOverlays();
}

function scrollDown() {
    // ensure we're not scrolling beyond the background..
    const scrollDelta = maxBgScrollOffset - bgScrollOffset >= scrollInterval
        ? scrollInterval
        : maxBgScrollOffset - bgScrollOffset;
    if (scrollDelta === 0) 
        return;
    
    // scroll the viewport down
    bgScrollOffset += scrollDelta;
    tmScrollOffset = (tmScrollOffset + scrollDelta) % 224;
    
    // redraw the last row on the viewport
    const lastTmRowOnViewport = ((tmScrollOffset + 191) % 224) >> 3;
    const lastBgRowOnViewport = (bgScrollOffset + 191) >> 3;
    setTilemapVisRow(lastTmRowOnViewport, lastBgRowOnViewport);    
    
    updateOffsetLabels();
    updateBackgroundOverlays();
    updateTilemapOverlays();
}

function setTilemapVisRow(tilemapRowIndex, backgroundRowIndex) {
    tilemapRow = tilemapRows[tilemapRowIndex];
    tilemapRow.classList.add("bg");
    tilemapRow.style.setProperty("background-position-y", `-${8 * backgroundRowIndex}px`);
}

function updateOffsetLabels() {
    bgScrollValEl.innerText = bgScrollOffset;
    tmScrollValEl.innerText = tmScrollOffset;
}

function updateBackgroundOverlays() {
    bgShadow1El.style.setProperty("top", 0);
    bgShadow1El.style.setProperty("height", `${bgScrollOffset}px`);
    bgOutlineEl.style.setProperty("top", `${bgScrollOffset}px`);
    bgShadow2El.style.setProperty("top", `${bgScrollOffset + 192}px`);
    bgShadow2El.style.setProperty("bottom", 0);
}    

function updateTilemapOverlays() {
    if (tmScrollOffset <= 32) { // 1 visible outline element, 2 visible shadow elements
        tmShadow1El.style.setProperty("top", 0);
        tmShadow1El.style.setProperty("height", `${tmScrollOffset}px`);
        tmOutline1El.style.setProperty("top", `${tmScrollOffset}px`);
        tmShadow2El.style.setProperty("display", "block");
        tmShadow2El.style.setProperty("bottom", 0);
        tmShadow2El.style.setProperty("height", `${32 - tmScrollOffset}px`);
        tmOutline2El.style.setProperty("display", "none");
        tilemapEl.classList.remove("v-clip");
    }    
    else { // 1 visible shadow element, 2 visible outline element
        tmOutline2El.style.setProperty("display", "block");
        tmOutline2El.style.setProperty("top", `${tmScrollOffset - 224}px`);
        tmShadow1El.style.setProperty("top", `${tmScrollOffset - 32}px`);
        tmShadow1El.style.setProperty("height", "32px");
        tmOutline1El.style.setProperty("top", `${tmScrollOffset}px`);
        tmShadow2El.style.setProperty("display", "none");
        tilemapEl.classList.add("v-clip");
    }    
}    

// the % operator returns a negative result for negative numerator
// this function always returns a positive result
function mod(n, d) {
    return ((n % d) + d) % d;
}
