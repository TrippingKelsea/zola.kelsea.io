// Terminal Enhancement Scripts

document.addEventListener('DOMContentLoaded', function() {
    // Add typing effect to the home page
    const terminalOutput = document.querySelector('.terminal-output');

    if (terminalOutput && window.location.pathname === '/') {
        addBootSequence();
    }

    // Add keyboard shortcuts
    addKeyboardShortcuts();

    // Add terminal command hints
    addCommandHints();

    // Enhance link interactions
    enhanceLinks();
});

// Boot sequence animation (optional, can be enabled)
function addBootSequence() {
    // This can be enabled for a cool boot effect on first load
    const hasBooted = sessionStorage.getItem('terminal_booted');

    if (!hasBooted && window.location.pathname === '/') {
        // sessionStorage.setItem('terminal_booted', 'true');
        // Add boot animation here if desired
    }
}

// Keyboard shortcuts
// Disabled intrusive shortcuts that override browser defaults
// Users can still navigate with standard keyboard navigation (Tab, Enter, etc.)
function addKeyboardShortcuts() {
    // Only enable if user explicitly wants them (check localStorage)
    if (localStorage.getItem('terminalShortcuts') === 'enabled') {
        document.addEventListener('keydown', function(e) {
            // Custom shortcuts that don't interfere with browser defaults
            // Using Alt instead of Ctrl to avoid conflicts
            if (e.altKey && e.key === 'b') {
                e.preventDefault();
                window.location.href = '/blog';
            }

            if (e.altKey && e.key === 'h') {
                e.preventDefault();
                window.location.href = '/';
            }
        });
    }
}

// Add command hints on hover
function addCommandHints() {
    const navLinks = document.querySelectorAll('.nav-links a');

    navLinks.forEach(link => {
        link.addEventListener('mouseenter', function() {
            const hint = this.getAttribute('data-command');
            if (hint) {
                console.log(`$ ${hint}`);
            }
        });
    });
}

// Enhance link clicks with terminal feel
function enhanceLinks() {
    const links = document.querySelectorAll('a:not([target="_blank"])');

    links.forEach(link => {
        if (link.hostname === window.location.hostname) {
            link.addEventListener('click', function(e) {
                // Add a subtle flash effect on click
                this.style.textShadow = '0 0 15px var(--glow-color)';
                setTimeout(() => {
                    this.style.textShadow = '';
                }, 150);
            });
        }
    });
}

// Typing effect utility (can be used for custom effects)
function typeWriter(element, text, speed = 50, callback) {
    let i = 0;
    element.innerHTML = '';

    function type() {
        if (i < text.length) {
            element.innerHTML += text.charAt(i);
            i++;
            setTimeout(type, speed);
        } else if (callback) {
            callback();
        }
    }

    type();
}

// Matrix rain effect for background (optional, can be enabled)
function createMatrixRain() {
    const canvas = document.createElement('canvas');
    canvas.style.position = 'fixed';
    canvas.style.top = '0';
    canvas.style.left = '0';
    canvas.style.width = '100%';
    canvas.style.height = '100%';
    canvas.style.zIndex = '0';
    canvas.style.opacity = '0.05';
    canvas.style.pointerEvents = 'none';

    document.body.insertBefore(canvas, document.body.firstChild);

    const ctx = canvas.getContext('2d');
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;

    const chars = '01アイウエオカキクケコサシスセソタチツテトナニヌネノ';
    const fontSize = 14;
    const columns = canvas.width / fontSize;
    const drops = Array(Math.floor(columns)).fill(1);

    function draw() {
        ctx.fillStyle = 'rgba(0, 0, 0, 0.05)';
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        ctx.fillStyle = '#0f0';
        ctx.font = fontSize + 'px monospace';

        for (let i = 0; i < drops.length; i++) {
            const text = chars[Math.floor(Math.random() * chars.length)];
            ctx.fillText(text, i * fontSize, drops[i] * fontSize);

            if (drops[i] * fontSize > canvas.height && Math.random() > 0.975) {
                drops[i] = 0;
            }
            drops[i]++;
        }
    }

    // Uncomment to enable matrix rain
    // setInterval(draw, 33);
}

// Console Easter Egg
console.log(`
 _  _______ _     ____  _____    _
| |/ / ____| |   / ___|| ____|  / \\
| ' /|  _| | |   \\___ \\|  _|   / _ \\
| . \\| |___| |___ ___) | |___ / ___ \\
|_|\\_\\_____|_____|____/|_____/_/   \\_\\

Welcome to kelsea.io!

Accessibility features enabled:
- Full keyboard navigation (Tab, Enter, Space)
- Screen reader compatible
- WCAG AA compliant colors
- Reduced motion support

Optional keyboard shortcuts disabled by default.
To enable: localStorage.setItem('terminalShortcuts', 'enabled')
Then: Alt+H (home), Alt+B (blog)

Happy browsing!
`);

// Performance: Reduce animations on low-end devices
if (navigator.hardwareConcurrency && navigator.hardwareConcurrency < 4) {
    document.body.classList.add('reduced-motion');
}
