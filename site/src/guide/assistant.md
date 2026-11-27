---
title: The study assistant
lede: Ask about a passage, a chapter or a book, and keep the answers as notes.
---

The assistant answers beside the page, in the inspector on the right where the notes column sits. There are three ways in.

## Three ways in

- **Ask About This Passage.** In the markup menu, it opens the assistant on the selected words with the selection prompts under About the passage: Explain this passage, Define the words and Compare translations. Click one to send it, or type a question.
- **Ask About This Chapter.** Right-click the running head and choose it to open the assistant on the chapter in view with the chapter prompts. Each is a tile with its title over a sentence on what comes back. Prompts you add are listed last, under Your prompts.
- **<kbd>⇧</kbd><kbd>⌘</kbd><kbd>A</kbd>.** The shortcut, the Assistant button in the toolbar, Assistant › Show Assistant and "Ask the Assistant" in <kbd>⌘</kbd><kbd>K</kbd> all open it on the selection when text is selected. Otherwise they reopen the open conversation, or ask "Include where you are?" with buttons for the chapter, the book and No context.

The chapter prompts come in three sections:

- Get oriented: Catch me up, Set the scene, Summarize this chapter and Outline this chapter.
- Dig in: Name the key themes, Find cross-references, Identify people and places, Explain the hard verses and Study the key words.
- Take it with you: Write reflection questions and Suggest a memory verse.

A book conversation follows you from chapter to chapter and tells the model when you move. No context sends nothing about where you are. The new-conversation menu (the + button) starts a new conversation on the chapter, the book or No context. Assistant › New Conversation… does the same and always asks "Include where you are?". <kbd>Esc</kbd> or the close button goes back to the notes column.

## Replies

<kbd>Return</kbd> sends and <kbd>⇧</kbd><kbd>Return</kbd> starts a new line. Stop ends a reply early and keeps what arrived. Each reply names who answered: On-device, `Claude · claude-opus-5-5`, `OpenAI · gpt-5`, or the custom endpoint's host. A reply that ended early says so beside that name: Stopped, Cut short, Declined partway or Ended early.

{% shot "assistant", "The assistant open beside Psalm 1, with the prompt Name the key themes sent and a numbered reply marked On-device", "lazy", "(min-width: 65rem) 43rem, 100vw" %}

Copy puts a reply on the clipboard. Add as Note saves it under its question as a note on the selection, added to the note already there or on a new underline. For a chapter, book or general conversation it saves a [chapter note]({{ '/guide/notes/' | url }}). It then opens the note in the notes column for editing. Once a reply is saved the button reads Show Note. If you delete that note, it reads Add as Note again.

Try Again resends a question that got no answer, after a failure or a stop. It goes to the same provider if Settings still send questions there, and otherwise to whoever answers now.

<div class="table-scroll">

| Command | Shortcut |
|---|---|
| Show Assistant / Show Notes | <kbd>⇧</kbd><kbd>⌘</kbd><kbd>A</kbd> |
| New Conversation… | <kbd>⌃</kbd><kbd>⌘</kbd><kbd>N</kbd> |
| Try Again | <kbd>⌘</kbd><kbd>R</kbd> |
| Copy Last Reply | <kbd>⇧</kbd><kbd>⌘</kbd><kbd>C</kbd> |
| Add Last Reply as Note | <kbd>⇧</kbd><kbd>⌘</kbd><kbd>S</kbd> |
| Stop Answering | <kbd>⌘</kbd><kbd>.</kbd> |

</div>

These are in the Assistant menu.

## Who answers

Apple's on-device model answers by default, on a Mac or iPhone with Apple Intelligence turned on. In Automatic, longer passages go to a cloud provider if you have added a key: Claude first, then OpenAI, then a custom endpoint. Without a key, the panel says the passage is too long and offers Settings.

For a chapter that would not fit on the device, Catch me up sends only the first and last five verses of the previous chapter. Compare translations on the device lists at most three other translations.

Settings › Assistant sets who answers: Automatic, On-device, Claude, OpenAI or Custom endpoint. It also holds your keys, the model names (`claude-opus-5-5` and `gpt-5` by default) and a custom OpenAI-compatible endpoint, such as Ollama or LM Studio. A key is saved as you type. Keys are kept in the Keychain, never in the app's settings, and the app stores them so that iCloud Keychain can carry them to your other devices.

## Your prompts

Settings › Prompts edits the study prompts, grouped under the same sections as the panel. You can turn a prompt on or hide it, rename it, edit its summary and text, reorder it, add your own, and restore an edited built-in prompt to its original title, summary and text.

## Conversations

Conversations are saved with their chapter. The history menu lists this chapter's and this book's conversations, and can delete the open one. The Notes window lists them all under Threads, and opening one there opens its chapter and the conversation. <kbd>⌘</kbd><kbd>Z</kbd> undoes deleting a conversation. See [The Notes window]({{ '/guide/notes-window/' | url }}).

## On the iPhone

The Ask tab is the assistant, with the Mac's prompts and conversations. Ask About This Passage on a selection opens it over the page.
