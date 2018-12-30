const handlers = [];

if (navigator.serviceWorker) {
  navigator.serviceWorker.addEventListener('message', (event) => {
    handlers.forEach((handler) => handler(event.data));
  });
}

const addMessageHandler = (handler) => {
  handlers.push(handler);
};

export default addMessageHandler;
