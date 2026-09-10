// Variables
const body = document.body;
const header = document.querySelector('.sol-header');
const scrollUp = 'scroll-up';
const scrollDown = 'scroll-down';
const openMenuButton = document.getElementById('sol-open-menu-button');
const headerMenuPrimary = document.querySelector('.sol-header-menu-primary');
const headerMenuSecondary = document.querySelector(
    '.sol-header-menu-secondary'
);
const headerMenuMain = document.querySelector('.sol-header-menu-main');
const closeHeaderMenuButton = document.querySelector(
    '.sol-close-header-button'
);
let lastScroll = 0;

// Event Listeners
window.addEventListener('scroll', () => {
    const currentScroll = window.scrollY;

    if (currentScroll <= 0) {
        body.classList.remove(scrollUp);
        return;
    }

    if (currentScroll > lastScroll && !body.classList.contains(scrollDown)) {
        // down
        body.classList.remove(scrollUp);
        body.classList.add(scrollDown);
    } else if (
        currentScroll < lastScroll &&
        body.classList.contains(scrollDown)
    ) {
        // up
        body.classList.remove(scrollDown);
        body.classList.add(scrollUp);
    }
    lastScroll = currentScroll;
});

openMenuButton.addEventListener('click', function() {
    document.getElementById('mobile-menu').classList.toggle('hidden');
});