document.addEventListener('DOMContentLoaded', () => {
    gsap.registerPlugin(ScrollTrigger);

    // Initial Hero Animation
    const heroTl = gsap.timeline();
    heroTl.from('.reveal h1', {
        y: 200,
        duration: 1.5,
        ease: 'power4.out'
    })
    .from('.fade-in', {
        opacity: 0,
        y: 30,
        duration: 1,
        stagger: 0.2
    }, '-=0.8');

    // Parallax Effect
    gsap.to('.hero-parallax', {
        scrollTrigger: {
            trigger: '.hero',
            start: 'top top',
            end: 'bottom top',
            scrub: true
        },
        y: (i, target) => {
            const speed = target.dataset.speed || 0.5;
            return speed * 300;
        }
    });

    // Staggered Product Entrance
    ScrollTrigger.batch('.product-card', {
        onEnter: (elements) => {
            gsap.from(elements, {
                opacity: 0,
                y: 50,
                stagger: 0.15,
                duration: 0.8,
                ease: 'power2.out'
            });
        },
        start: 'top 85%'
    });
});
