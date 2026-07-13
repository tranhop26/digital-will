document.addEventListener("DOMContentLoaded", () => {
  console.log("Digital Will Landing Page Loaded");

  // Subtle scroll animation or interactive effects
  const steps = document.querySelectorAll(".step-card");
  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.style.opacity = 1;
        entry.target.style.transform = "translateY(0)";
      }
    });
  }, { threshold: 0.1 });

  steps.forEach((step) => {
    step.style.opacity = 0;
    step.style.transform = "translateY(20px)";
    step.style.transition = "opacity 0.6s ease-out, transform 0.6s ease-out";
    observer.observe(step);
  });
});
