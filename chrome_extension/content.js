// document.addEventListener('mouseup', function (e) {
//   let selectedText = window.getSelection().toString().trim();
//   let isShowingMenu = document.getElementById('customTextMenu');
//   if (selectedText.length > 0 && !isShowingMenu) {
//     showCustomMenu(e.clientX, e.clientY, selectedText);
//   }
// });

// function showCustomMenu(x, y, text) {
//   const existingMenu = document.getElementById('customTextMenu');

//   // Remove existing menu if it's already there
//   if (existingMenu) {
//     existingMenu.remove();
//   }

//   // Create the container for our custom context menu
//   const menu = document.createElement('div');
//   menu.id = 'customTextMenu';
//   menu.style.cssText = `position: fixed; left: ${x}px; top: ${y}px; z-index:1000;background:white;border:1px solid black;padding:5px`;

//   // Define an array of objects representing our buttons/options in the context menu.
//   const options = [
//     { commandType: 'grammar', label: 'Check grammar' },
//     { commandType: 'answer_with_tags', label: 'Answer with tags' },
//     { commandType: 'to_eng', label: 'Translate to English' },
//     { commandType: 'to_rus', label: 'Translate to Russian' },
//     { commandType: 'close', label: 'Close' }
//   ];

//   options.forEach(option => {
//     const buttonElement = document.createElement("div");
//     buttonElement.textContent = option.label;

//     // Attach click listener programmatically.
//     buttonElement.addEventListener("click", () => {
//       menu.remove();
//       if (option.commandType === 'close') {
//         return;
//       }
//       openFlutterApp(option.commandType, text);
//     });

//     // Append each newly created div/button element into our main "menu" container.
//     menu.appendChild(buttonElement);
//   });

//   document.body.appendChild(menu);
// }

// window.openFlutterApp = function (type, text) {
//   const url = `fluentgpt://?command=${type}&text=${encodeURIComponent(text)}`
//   window.open(url, '_blank')
//   console.log(`Opening Flutter app with URL:${url}`);
// }

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  window.open(request.url, '_blank');
});