document.addEventListener("DOMContentLoaded", function() {
    var metaTag = document.querySelector('meta[name="description"]');
    var name = "";
    if (metaTag) {
        var content = metaTag.getAttribute('content');
        var match = content.match(/Documentation for (.+?)\./);
        if (match && match[1]) {
            name = match[1];
            name = name.concat(".jl");
        }
    }
    var footerMessageElement = document.querySelector('p.footer-message');
    var suffix = 'stable/';
    if (footerMessageElement && (footerMessageElement.textContent.includes('+dev') || footerMessageElement.textContent.includes('-dev'))) {
        suffix = 'dev/';
    } else if (window.location.href.includes('/dev/')) {
        suffix = 'dev/';
    }
    var packages = [
        "QuantumPropagators.jl",
        "QuantumGradientGenerators.jl",
        "ParameterizedQuantumControl.jl",
        "Krotov.jl",
        "GRAPE.jl",
        "TwoQubitWeylChamber.jl",
        "QuantumControl.jl",
    ];
    var dropdownItems = packages.map(function(packageName) {
        return `<a class="nav-link nav-item ${name === packageName ? 'current' : ''}" href="https://juliaquantumcontrol.github.io/${packageName}/${suffix}">${packageName}</a>`;
    }).join('');
    var isSecondaryPackage = !(name === "QuantumControl.jl" || name === "QuantumPropagators.jl" || name.includes('Tutorials'));
    var navElement = document.createElement('nav');
    navElement.id = "topbar-nav";
    navElement.innerHTML = `
        <a href="https://github.com/JuliaQuantumControl" class="nav-link">
            <img src="https://juliaquantumcontrol.github.io/QuantumControl.jl/dev/assets/topbar/org_logo.svg" onload="this.style.height = getComputedStyle(document.getElementById('topbar-nav')).height" class="nav-link nav-item" alt="Logo">
        </a>
        <div id="nav-items">
          <div class="nav-dropdown">
            <button class="nav-item dropdown-label ${isSecondaryPackage ? 'current' : ''}">JuliaQuantumControl</button>
            <ul class="nav-dropdown-container">
              ${dropdownItems}
            </ul>
          </div>
          <a class="nav-link nav-item ${name === 'QuantumPropagators.jl' ? 'current' : ''}" href="${name === 'QuantumPropagators.jl' ? '' : 'https://juliaquantumcontrol.github.io/QuantumPropagators.jl/' + suffix}">QuantumPropagators.jl</a>
          <a class="nav-link nav-item ${name === 'QuantumControl.jl' ? 'current' : ''}" href="${name === 'QuantumControl.jl' ? '' : 'https://juliaquantumcontrol.github.io/QuantumControl.jl/' + suffix}">QuantumControl.jl</a>
          <a class="nav-link nav-item ${name.includes('Tutorials') ? 'current' : ''}" href="${name.includes('Tutorials') ? '' : 'https://juliaquantumcontrol.github.io/Tutorials/'}">Tutorials</a>
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
