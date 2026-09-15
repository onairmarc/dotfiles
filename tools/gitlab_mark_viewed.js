const unviewed = [...document.querySelectorAll('input[type="checkbox"]')]
    .filter(input =>
        !input.checked &&
        /viewed/i.test(
            `${input.getAttribute('aria-label') ?? ''} ` +
            `${input.closest('label')?.textContent ?? ''} ` +
            `${document.querySelector(`label[for="${input.id}"]`)?.textContent ?? ''}`
        )
    );

unviewed.forEach((input, index) => {
    setTimeout(() => input.click(), index * 100);
});

console.log(`Marked ${unviewed.length} file(s) as viewed.`);