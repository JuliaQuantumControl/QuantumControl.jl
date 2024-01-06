document.addEventListener("DOMContentLoaded", function() {
    var navElement = document.createElement('nav');
    navElement.id = "multi-page-nav";
    navElement.innerHTML = `
        <a class="nav-link nav-item" href="">Logo</a>
        <div class="hidden-on-mobile" id="nav-items">
          <div class="nav-dropdown">
            <button class="nav-item dropdown-label">JuliaQuantumControl</button>
            <ul class="nav-dropdown-container">
              <a class="nav-link nav-item" href="">QuantumPropagators.jl</a>
              <a class="nav-link nav-item" href="">QuantumControlBase.jl</a>
              <a class="nav-link nav-item" href="">QuantumGradientGenerators.jl</a>
              <a class="nav-link nav-item" href="">Krotov.jl</a>
              <a class="nav-link nav-item current" href="">GRAPE.jl</a>
              <a class="nav-link nav-item" href="">TwoQubitWeylChember.jl</a>
              <a class="nav-link nav-item" href="">QuantumControl.jl</a>
            </ul>
          </div>
          <a class="nav-link nav-item current" href="">QuantumPropagators.jl</a>
          <a class="nav-link nav-item" href="">QuantumControl.jl</a>
          <a class="nav-link nav-item" href="">Examples</a>
        </div>
        <button id="multidoc-toggler">
            <svg viewbox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                <path d="M3 6h18v2H3V6m0 5h18v2H3v-2m0 5h18v2H3v-2Z"></path>
            </svg>
        </button>`;

    var body = document.body;
    body.insertBefore(navElement, body.firstChild);
});

function topbarInjector() {
  document
    .getElementById("multidoc-toggler")
    .addEventListener("click", function () {
      document.getElementById("nav-items").classList.toggle("hidden-on-mobile");
    });
  document.body.addEventListener("click", function (ev) {
    const thisIsExpanded = ev.target.matches(".nav-expanded > .dropdown-label");
    if (!ev.target.matches(".nav-dropdown-container")) {
      Array.prototype.forEach.call(
        document.getElementsByClassName("dropdown-label"),
        function (el) {
          el.parentElement.classList.remove("nav-expanded");
        }
      );
    }
    if (!thisIsExpanded && ev.target.matches(".dropdown-label")) {
      ev.target.parentElement.classList.add("nav-expanded");
    }
  });
}

if (
  document.readyState === "complete" ||
  document.readyState === "interactive"
) {
  // call on next available tick
  setTimeout(topbarInjector, 1);
} else {
  document.addEventListener("DOMContentLoaded", topbarInjector);
}
