// background.js
console.log('Fluent GPT. Background script is running');

// Create context menu items
const options = [
  { commandType: 'grammar', label: 'Check grammar' },
  { commandType: 'answer_with_tags', label: 'Answer with tags' },
  { commandType: 'to_eng', label: 'Translate to English' },
  { commandType: 'to_rus', label: 'Translate to Russian' }
];

options.forEach(option => {
  chrome.contextMenus.create({
    id: option.commandType,
    title: option.label,
    contexts: ['selection']
  });
});

// Add click event listener
chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (info.selectionText) {
    const url = `fluentgpt://?command=${info.menuItemId}&text=${encodeURIComponent(info.selectionText)}`
    chrome.tabs.sendMessage(tab.id, {url: url});
  }
});