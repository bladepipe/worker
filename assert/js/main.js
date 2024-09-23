const config = {
    'Docker': [
        {
            title: 'Install Worker',
            link: 'https://download.bladepipe.com/docker/install_run.sh',
            docTitle: 'Install Worker (Docker)',
            docLink: 'https://doc.bladepipe.com/productOP/docker/install_worker_docker',
            command: '/bin/bash -c "$(curl -fsSL https://download.bladepipe.com/docker/install_run.sh)"',
        },
        {
            title: 'Upgrade Worker',
            link: 'https://download.bladepipe.com/docker/upgrade.sh',
            docTitle: 'Upgrade Worker (Docker)',
            docLink: 'https://doc.bladepipe.com/productOP/docker/upgrade_worker_docker',
            command: '/bin/bash -c "$(curl -fsSL https://download.bladepipe.com/docker/upgrade.sh)"',
        },
    ],
    'Binary': [
        {
            title: 'Install Worker',
            link: 'https://download.bladepipe.com/binary/install_run.sh',
            docTitle: 'Install Worker (Binary)',
            docLink: 'https://doc.bladepipe.com/productOP/binary/install_worker_binary',
            command: '/bin/bash -c "$(curl -fsSL https://download.bladepipe.com/binary/install_run.sh)"',
        },
        {
            title: 'Upgrade Worker',
            link: 'https://download.bladepipe.com/binary/upgrade.sh',
            docTitle: 'Upgrade Worker (Binary)',
            docLink: 'https://doc.bladepipe.com/productOP/binary/upgrade_worker_binary',
            command: '/bin/bash -c "$(curl -fsSL https://download.bladepipe.com/binary/upgrade.sh)"',
        },
    ]
}

const e = sel => document.querySelector(sel)

const appendHtml = function (div, html) {
    div.insertAdjacentHTML('beforeend', html)
}

const toggleClass = function (element, className) {
    if (element.classList.contains(className)) {
        element.classList.remove(className)
    } else {
        element.classList.add(className)
    }
}

function headTemplate(head) {
    return `<h2>${head}</h2>`
}

function contentTemplate(title, link, docTitle, docLink, command) {
    const encodedCommand = encodeURIComponent(command);
    return `<div class="script-section">
                <h3>${title}</h3>
                <div class="code-container">
                    <div id="pre">
                        <div id="code">
                            <span class="code-command">/bin/bash -c</span> 
                            <span>"</span><span class="code-url">$(curl -fsSL ${link})</span><span style="margin-right: 0.75rem;">"</span>
                        </div>
                    </div>
                    <button class="copy-btn" data-command="${encodedCommand}" onclick="copyToClipboard(this)">Copy</button>
                </div>
                <p>For more details, please refer to the official documentation:
                    <a href="${docLink}" target="_blank">${docTitle}</a>.
                </p>
            </div>`
}

function copyToClipboard(button) {
    const code = decodeURIComponent(button.dataset.command)
    const tempInput = document.createElement("textarea")
    tempInput.value = code
    document.body.appendChild(tempInput)

    tempInput.select()
    document.execCommand("copy")

    document.body.removeChild(tempInput)

    button.textContent = "Copied!"
    button.classList.add("success")

    setTimeout(() => {
        button.textContent = "Copy"
        button.classList.remove("success")
    }, 2000)
}

function __main() {
    document.onreadystatechange = () => {
        if (document.readyState === "complete") {
            toggleClass(e("#spinner"), "hide")
        }
    }

    let hereWeGo = ''

    for (let head in config) {
        let content = config[head]
        let sector = headTemplate(head)

        content.forEach(item => {
            sector += contentTemplate(item.title, item.link, item.docTitle, item.docLink, item.command)
        })

        hereWeGo += sector
    }

    appendHtml(e('#here-we-go'), hereWeGo)
}

__main()