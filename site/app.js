"use strict";

const root = document.documentElement;
const header = document.querySelector("[data-header]");
const nav = document.querySelector("[data-nav]");
const navToggle = document.querySelector("[data-nav-toggle]");
const themeToggle = document.querySelector("[data-theme-toggle]");

const savedTheme = localStorage.getItem("bootprint-theme");
if (savedTheme === "light" || savedTheme === "dark") root.dataset.theme = savedTheme;

function updateThemeLabel() {
  const isDark = root.dataset.theme === "dark";
  themeToggle.setAttribute("aria-label", `Switch to ${isDark ? "light" : "dark"} theme`);
}

updateThemeLabel();

themeToggle.addEventListener("click", () => {
  root.dataset.theme = root.dataset.theme === "dark" ? "light" : "dark";
  localStorage.setItem("bootprint-theme", root.dataset.theme);
  updateThemeLabel();
});

navToggle.addEventListener("click", () => {
  const open = nav.classList.toggle("open");
  navToggle.setAttribute("aria-expanded", String(open));
});

nav.addEventListener("click", (event) => {
  if (event.target instanceof HTMLAnchorElement) {
    nav.classList.remove("open");
    navToggle.setAttribute("aria-expanded", "false");
  }
});

window.addEventListener("scroll", () => header.classList.toggle("scrolled", window.scrollY > 12), { passive: true });

document.querySelectorAll("[data-copy]").forEach((button) => {
  button.addEventListener("click", async () => {
    const original = button.textContent;
    try {
      await navigator.clipboard.writeText(button.dataset.copy);
      button.textContent = "Copied";
    } catch {
      button.textContent = "Select text";
    }
    window.setTimeout(() => { button.textContent = original; }, 1600);
  });
});

const findings = {
  runtime: {
    severity: "WARNING",
    severityClass: "warning",
    title: "Ruby patch-level drift",
    description: "Source uses Ruby 3.4.2 while the target uses 3.4.1. Behavior and bundled library fixes can differ.",
    source: "ruby 3.4.2",
    target: "ruby 3.4.1",
    remediation: "Pin one Ruby version in .ruby-version and CI."
  },
  native: {
    severity: "CRITICAL",
    severityClass: "critical",
    title: "Native extension platform mismatch",
    description: "The bundle contains an arm64-darwin extension while the deployment runtime is x86_64-linux.",
    source: "arm64-darwin",
    target: "x86_64-linux",
    remediation: "Add x86_64-linux to Gemfile.lock and rebuild the deployment bundle."
  },
  rails: {
    severity: "ERROR",
    severityClass: "error",
    title: "Queue adapter mismatch",
    description: "Development uses the async adapter while production is configured for Sidekiq-backed jobs.",
    source: "async",
    target: "sidekiq",
    remediation: "Align Active Job configuration and verify the production worker process."
  }
};

const panel = document.querySelector("[data-tab-panel]");
document.querySelectorAll("[data-tab]").forEach((tab) => {
  tab.addEventListener("click", () => {
    document.querySelectorAll("[data-tab]").forEach((item) => item.setAttribute("aria-selected", String(item === tab)));
    const finding = findings[tab.dataset.tab];
    panel.innerHTML = `
      <div class="severity-label ${finding.severityClass}">${finding.severity}</div>
      <h3>${finding.title}</h3>
      <p>${finding.description}</p>
      <dl><div><dt>Source</dt><dd>${finding.source}</dd></div><div><dt>Target</dt><dd>${finding.target}</dd></div></dl>
      <div class="remediation"><span>Recommended fix</span><code>${finding.remediation}</code></div>`;
  });
});

const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
if (reducedMotion || !("IntersectionObserver" in window)) {
  document.querySelectorAll(".reveal").forEach((element) => element.classList.add("visible"));
} else {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("visible");
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.12 });
  document.querySelectorAll(".reveal").forEach((element) => observer.observe(element));
}
