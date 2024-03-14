from get_versions import get_versions

def change_supported_builds(new_versions, playbook_file):
    with open(playbook_file, 'r') as file:
        data = file.read()

    start = data.find('<SupportedBuilds>')
    end = data.find('</SupportedBuilds>')
    old_content = data[start:end]
    old_content += '</SupportedBuilds>'

    new_content = '<SupportedBuilds>\n'
    for version in new_versions:
        new_content += '        <string>{}</string>\n'.format(version)
    new_content += '    </SupportedBuilds>'

    data = data.replace(old_content, new_content)

    with open(playbook_file, 'w') as file:
        file.write(data)

newest = get_versions()

new_versions = [
    newest[0],
    newest[1],
    newest[2],
    '19044',
    '19045',
    '22621',
    '22631'
    ]

playbook_file = 'src/playbook.conf'
change_supported_builds(new_versions, playbook_file)