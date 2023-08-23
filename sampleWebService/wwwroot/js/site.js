const uri = 'api/todoitems';
let todos = [];
let ajaxEnabled = false;

document.addEventListener('DOMContentLoaded', function () {
  var checkbox = document.querySelector('input[type="checkbox"]');

  checkbox.addEventListener('change', function () {
    toggleAJAX();
  });
});

function getIPAddress() {
  fetch("api/IPAddress")
    .then(response => response.json())
    .then(data => {
      if (data["ipAddress"] == "10.0.0.5") {
        document.getElementById("ip_address_span").innerHTML=data["ipAddress"] + " (Proxy)";
      } else {
        document.getElementById("ip_address_span").innerHTML=data["ipAddress"] + " (Not Proxy)";
      }        
    })
    .catch(error => console.error("unable to get ip address.", error));
}

function getItems() {
  if (ajaxEnabled) {
    const xhr = new XMLHttpRequest();
    xhr.onload = function () {
      if (xhr.status >= 200 && xhr.status < 300) {
        _displayItems(JSON.parse(xhr.response));
      } else {
        console.error('Unable to get items.');
      }
    }
    xhr.open('GET', uri);
    xhr.send();
  } else {
    fetch(uri)
      .then(response => response.json())
      .then(data => _displayItems(data))
      .catch(error => console.error('Unable to get items.', error));
  }
}

function addItem() {
  const addNameTextbox = document.getElementById('add-name');

  const item = {
    isComplete: false,
    name: addNameTextbox.value.trim()
  };

  if (ajaxEnabled) {
    const xhr = new XMLHttpRequest();
    xhr.onload = function () {
      if (xhr.status >= 200 && xhr.status < 300) {
        getItems();
        addNameTextbox.value = '';
      } else {
        console.error('Unable to add item.');
      }
    }
    xhr.open('POST', uri);
    xhr.setRequestHeader('Content-Type', 'application/json');
    xhr.send(JSON.stringify(item));
  } else {
    fetch(uri, {
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(item)
    })
      .then(response => response.json())
      .then(() => {
        getItems();
        addNameTextbox.value = '';
      })
      .catch(error => console.error('Unable to add item.', error));
  }
}

function deleteItem(id) {
  if (ajaxEnabled) {
    const xhr = new XMLHttpRequest();
    xhr.onload = function () {
      if (xhr.status >= 200 && xhr.status < 300) {
        getItems();
      } else {
        console.error('Unable to delete item.');
      }
    }
    xhr.open('DELETE', `${uri}/${id}`);
    xhr.send();
  } else {
    fetch(`${uri}/${id}`, {
      method: 'DELETE'
    })
    .then(() => getItems())
    .catch(error => console.error('Unable to delete item.', error));
  }
}

function displayEditForm(id) {
  const item = todos.find(item => item.id === id);
  
  document.getElementById('edit-name').value = item.name;
  document.getElementById('edit-id').value = item.id;
  document.getElementById('edit-isComplete').checked = item.isComplete;
  document.getElementById('editForm').style.display = 'block';
}

function updateItem() {
  const itemId = document.getElementById('edit-id').value;
  const item = {
    id: parseInt(itemId, 10),
    isComplete: document.getElementById('edit-isComplete').checked,
    name: document.getElementById('edit-name').value.trim()
  };

  if (ajaxEnabled) {
    const xhr = new XMLHttpRequest();
    xhr.onload = function () {
      if (xhr.status >= 200 && xhr.status < 300) {
        getItems();
      } else {
        console.error('Unable to update item.');
      }
    }
    xhr.open('PUT', `${uri}/${itemId}`);
    xhr.setRequestHeader('Content-Type', 'application/json');
    xhr.send(JSON.stringify(item));
  } else {
    fetch(`${uri}/${itemId}`, {
      method: 'PUT',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(item)
    })
    .then(() => getItems())
    .catch(error => console.error('Unable to update item.', error));
  }

  closeInput();

  return false;
}

function closeInput() {
  document.getElementById('editForm').style.display = 'none';
}

function _displayCount(itemCount) {
  const name = (itemCount === 1) ? 'to-do' : 'to-dos';

  document.getElementById('counter').innerText = `${itemCount} ${name}`;
}

function toggleAJAX() {
  if (ajaxEnabled) {
    ajaxEnabled = false;
  } else {
    ajaxEnabled = true;
  }
}

function _displayItems(data) {
  const tBody = document.getElementById('todos');
  tBody.innerHTML = '';

  _displayCount(data.length);

  const button = document.createElement('button');

  data.forEach(item => {
    let isCompleteCheckbox = document.createElement('input');
    isCompleteCheckbox.type = 'checkbox';
    isCompleteCheckbox.disabled = true;
    isCompleteCheckbox.checked = item.isComplete;

    let editButton = button.cloneNode(false);
    editButton.innerText = 'Edit';
    editButton.setAttribute('onclick', `displayEditForm(${item.id})`);

    let deleteButton = button.cloneNode(false);
    deleteButton.innerText = 'Delete';
    deleteButton.setAttribute('onclick', `deleteItem(${item.id})`);

    let tr = tBody.insertRow();
    
    let td1 = tr.insertCell(0);
    td1.appendChild(isCompleteCheckbox);

    let td2 = tr.insertCell(1);
    let textNode = document.createTextNode(item.name);
    td2.appendChild(textNode);

    let td3 = tr.insertCell(2);
    td3.appendChild(editButton);

    let td4 = tr.insertCell(3);
    td4.appendChild(deleteButton);
  });

  todos = data;
}
