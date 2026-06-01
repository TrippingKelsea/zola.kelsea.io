// Terminal Enhancement Scripts

document.addEventListener('DOMContentLoaded', function() {
    // Initialize theme switcher first (before any visual setup)
    initThemeSwitcher();

    // Initialize content warning reveal functionality
    initContentWarning();

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

// ==================================================================
// CONTENT WARNING / SPOILER REVEAL
// ==================================================================

function initContentWarning() {
    const revealButtons = document.querySelectorAll('.reveal-content-btn');

    revealButtons.forEach(button => {
        button.addEventListener('click', function() {
            revealContent(this);
        });

        // Also handle Enter and Space keys for accessibility
        button.addEventListener('keydown', function(e) {
            if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                revealContent(this);
            }
        });
    });
}

function revealContent(button) {
    const contentId = button.getAttribute('aria-controls');
    const contentElement = document.getElementById(contentId);
    const warningBox = button.closest('.content-warning');

    if (contentElement) {
        // Update ARIA attributes
        button.setAttribute('aria-expanded', 'true');
        contentElement.setAttribute('aria-hidden', 'false');

        // Remove blur and show content
        contentElement.classList.remove('content-hidden');
        contentElement.classList.add('content-revealed');

        // Hide the warning box
        if (warningBox) {
            warningBox.classList.add('warning-dismissed');
        }

        // Announce to screen readers
        announceContentRevealed();

        // Move focus to the content for keyboard users
        contentElement.setAttribute('tabindex', '-1');
        contentElement.focus();
    }
}

function announceContentRevealed() {
    // Create or update live region for screen reader announcement
    let announcer = document.getElementById('content-announcer');
    if (!announcer) {
        announcer = document.createElement('div');
        announcer.id = 'content-announcer';
        announcer.setAttribute('role', 'status');
        announcer.setAttribute('aria-live', 'polite');
        announcer.setAttribute('aria-atomic', 'true');
        announcer.className = 'sr-only';
        document.body.appendChild(announcer);
    }

    announcer.textContent = 'Content revealed. You may now read the chapter.';
}

// ==================================================================
// THEME SWITCHER
// ==================================================================

function initThemeSwitcher() {
    // Load saved theme preference from localStorage
    const savedTheme = localStorage.getItem('terminalTheme');
    if (savedTheme) {
        applyTheme(savedTheme);
    }

    // Add click handlers to theme buttons
    const themeButtons = document.querySelectorAll('.control-btn[data-theme]');
    themeButtons.forEach(button => {
        button.addEventListener('click', function() {
            const theme = this.getAttribute('data-theme');
            applyTheme(theme);
            localStorage.setItem('terminalTheme', theme);

            // Announce theme change for screen readers
            announceThemeChange(theme);
        });
    });
}

function applyTheme(theme) {
    // Apply theme to the document root
    document.documentElement.setAttribute('data-theme', theme);
}

function announceThemeChange(theme) {
    // Create a live region announcement for screen readers
    let announcer = document.getElementById('theme-announcer');
    if (!announcer) {
        announcer = document.createElement('div');
        announcer.id = 'theme-announcer';
        announcer.setAttribute('role', 'status');
        announcer.setAttribute('aria-live', 'polite');
        announcer.setAttribute('aria-atomic', 'true');
        announcer.className = 'sr-only';
        document.body.appendChild(announcer);
    }

    const themeNames = {
        'green': 'green',
        'amber': 'amber',
        'grey': 'greyscale'
    };

    announcer.textContent = `Terminal theme changed to ${themeNames[theme] || theme}`;
}

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

Theme Switcher:
- Use the three buttons in the terminal header
- Left (_) = Green | Middle (□) = Amber | Right (×) = Greyscale
- Your preference is saved automatically

Accessibility features enabled:
- Full keyboard navigation (Tab, Enter, Space)
- Screen reader compatible
- WCAG AAA compliant colors for all themes
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
