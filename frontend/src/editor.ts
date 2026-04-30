import * as monaco from 'monaco-editor';
import { invoke } from '@tauri-apps/api/core';
import { open } from '@tauri-apps/plugin-dialog';

interface Tab {
    id: string;
    path: string;
    name: string;
    isModified: boolean;
    language: string;
}

interface Project {
    id: string;
    name: string;
    path: string;
    is_active: boolean;
}

interface FileEntry {
    name: string;
    path: string;
    is_directory: boolean;
    is_hidden: boolean;
}

interface DirectoryListing {
    entries: FileEntry[];
    path: string;
}

interface WorkspaceState {
    id: string;
    name: string;
    path: string;
    open_files: string[];
    active_file: string | null;
    expanded_folders: string[];
}

class CodniaEditor {
    private editor: monaco.editor.IStandaloneCodeEditor | null = null;
    private tabs: Tab[] = [];
    private activeTabId: string | null = null;
    private projects: Project[] = [];
    private activeProject: Project | null = null;
    private expandedFolders: Set<string> = new Set();

    constructor() {
        this.initMonaco();
        this.initEventListeners();
        this.initSettings();
        this.loadProjects();
        (window as any).handleNewTabAction = (action: string) => this.handleNewTabAction(action);
    }

    private initSettings(): void {
        const toggleMinimap = document.getElementById('toggleMinimap') as HTMLInputElement;
        if (toggleMinimap) {
            const settings = this.loadSettings();
            toggleMinimap.checked = settings.minimap;
            if (this.editor) {
                this.editor.updateOptions({ minimap: { enabled: settings.minimap } });
            }
            toggleMinimap.addEventListener('change', (e) => {
                const checked = (e.target as HTMLInputElement).checked;
                this.updateMinimap(checked);
            });
        }
    }

    private async loadProjects(): Promise<void> {
        try {
            this.projects = await invoke<Project[]>('get_projects');
            this.renderProjectCards();
            const recent = await invoke<string[]>('get_recent_projects');
            console.log('Recent projects:', recent);
        } catch (e) {
            console.error('Failed to load projects:', e);
        }
    }

    private renderProjectCards(): void {
        const container = document.querySelector('.sidebar-section');
        if (!container) return;

        const existingCards = container.querySelectorAll('.project-card');
        existingCards.forEach(card => card.remove());

        const addBtn = container.querySelector('.add-project-btn');
        
        for (const project of this.projects) {
            const card = document.createElement('div');
            card.className = 'project-card' + (project.is_active ? ' active' : '');
            card.dataset.projectId = project.id;
            card.title = project.name;
            card.textContent = this.getInitials(project.name);
            card.addEventListener('click', () => this.setActiveProject(project.id));
            container.insertBefore(card, addBtn);
        }
    }

    private getInitials(name: string): string {
        return name.split(/[\s_-]+/).map(w => w[0]).join('').toUpperCase().slice(0, 2);
    }

    private async setActiveProject(projectId: string): Promise<void> {
        try {
            await invoke('set_active_project', { id: projectId });
            this.activeProject = this.projects.find(p => p.id === projectId) || null;
            
            document.querySelectorAll('.project-card').forEach(card => {
                card.classList.toggle('active', (card as HTMLElement).dataset.projectId === projectId);
            });

            this.activeProject = this.projects.find(p => p.id === projectId) || null;
            if (this.activeProject) {
                await this.loadDirectory(this.activeProject.path);
            }
        } catch (e) {
            console.error('Failed to set active project:', e);
        }
    }

    private async addProject(): Promise<void> {
        try {
            const selected = await open({
                directory: true,
                multiple: false,
                title: 'Select Project Folder'
            });

            if (selected) {
                const project = await invoke<Project>('add_project', { path: selected });
                this.projects.push(project);
                this.renderProjectCards();
                await this.setActiveProject(project.id);
            }
        } catch (e) {
            console.error('Failed to add project:', e);
        }
    }

    private async initMonaco(): Promise<void> {
        const container = document.getElementById('monaco-editor');
        if (!container) {
            console.error('Monaco editor container not found');
            return;
        }

        const settings = this.loadSettings();

        this.editor = monaco.editor.create(container, {
            value: '',
            language: 'plaintext',
            theme: 'vs-dark',
            fontSize: 13,
            fontFamily: 'SF Mono, Fira Code, Consolas, monospace',
            minimap: { enabled: settings.minimap },
            automaticLayout: true,
            scrollBeyondLastLine: false,
            lineNumbers: 'on',
            renderWhitespace: 'selection',
            tabSize: 4,
            insertSpaces: true,
            mouseWheelZoom: false,
        });

        this.editor.onDidChangeCursorPosition((e) => {
            const position = document.getElementById('statusPosition');
            if (position) {
                position.textContent = `Ln ${e.position.lineNumber}, Col ${e.position.column}`;
            }
        });

        this.editor.onDidChangeModelContent(() => {
            const model = this.editor?.getModel();
            if (model && this.activeTabId) {
                const tab = this.tabs.find(t => t.id === this.activeTabId);
                if (tab && !tab.isModified) {
                    tab.isModified = true;
                    this.updateTabUI(tab);
                }
            }
        });

        window.addEventListener('resize', () => {
            this.editor?.layout();
        });

        console.log('Codnia Monaco Editor initialized');
    }

    private loadSettings(): { minimap: boolean } {
        try {
            const saved = localStorage.getItem('codnia-settings');
            if (saved) {
                return JSON.parse(saved);
            }
        } catch (e) {
            console.error('Failed to load settings:', e);
        }
        return { minimap: false };
    }

    public saveSettings(settings: { minimap?: boolean }): void {
        const current = this.loadSettings();
        const updated = { ...current, ...settings };
        localStorage.setItem('codnia-settings', JSON.stringify(updated));
    }

    public updateMinimap(enabled: boolean): void {
        this.saveSettings({ minimap: enabled });
        if (this.editor) {
            this.editor.updateOptions({ minimap: { enabled } });
        }
    }

    private handleNewTabAction(action: string): void {
        switch (action) {
            case 'terminal':
                this.openTerminal();
                break;
            case 'opencode':
                this.runInTerminal('opencode .');
                break;
            case 'claude':
                this.runInTerminal('claude');
                break;
            case 'codex':
                this.runInTerminal('codex');
                break;
            case 'newfile':
                this.createNewFile();
                break;
        }
    }

    private openTerminal(): void {
        console.log('Opening terminal...');
        const tab: Tab = {
            id: `terminal-${Date.now()}`,
            path: '',
            name: 'Terminal',
            isModified: false,
            language: 'shell',
        };
        this.tabs.push(tab);
        this.activeTabId = tab.id;
        this.createTabUI(tab);
    }

    private runInTerminal(command: string): void {
        console.log('Running command:', command);
        this.openTerminal();
    }

    private createNewFile(): void {
        console.log('Creating new file...');
        if (this.editor) {
            this.editor.setValue('');
            const model = this.editor.getModel();
            if (model) {
                monaco.editor.setModelLanguage(model, 'plaintext');
            }
        }
        const tab: Tab = {
            id: `newfile-${Date.now()}`,
            path: '',
            name: 'untitled',
            isModified: true,
            language: 'plaintext',
        };
        this.tabs.push(tab);
        this.activeTabId = tab.id;
        this.createTabUI(tab);
        this.updateTabUI(tab);
    }

    private initEventListeners(): void {
        const addProjectBtn = document.querySelector('.add-project-btn');
        if (addProjectBtn) {
            addProjectBtn.addEventListener('click', () => this.addProject());
        }

        document.querySelectorAll('.tab-action-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const id = (e.currentTarget as HTMLElement).id;
                this.handleActionButtonClick(id);
            });
        });
    }

    private handleActionButtonClick(id: string): void {
        switch (id) {
            case 'btnExplorer':
                this.togglePanel('panelExplorer');
                break;
            case 'btnTasks':
                this.togglePanel('panelTasks');
                break;
            case 'btnApi':
                this.togglePanel('panelApi');
                break;
            case 'btnGit':
                this.togglePanel('panelGit');
                break;
            case 'btnSearch':
                this.showSearchPanel();
                break;
        }
    }

    private togglePanel(panelId: string): void {
        const panel = document.getElementById(panelId);
        if (panel) {
            panel.classList.toggle('hidden');
        }
    }

    private async loadDirectory(path: string): Promise<void> {
        try {
            const listing = await invoke<DirectoryListing>('list_directory', { path });
            this.renderFileTree(listing.entries);
        } catch (e) {
            console.error('Failed to load directory:', e);
        }
    }

    private renderFileTree(entries: FileEntry[]): void {
        const container = document.getElementById('fileTree');
        if (!container) return;

        container.innerHTML = '';

        for (const entry of entries) {
            const item = document.createElement('div');
            item.className = 'tree-item' + (entry.is_directory ? ' folder' : '');
            item.dataset.path = entry.path;

            if (entry.is_directory) {
                const arrow = document.createElement('span');
                arrow.className = 'tree-arrow';
                arrow.innerHTML = '<svg class="tree-arrow-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="9 18 15 12 9 6"/></svg>';
                item.appendChild(arrow);
            }

            const icon = document.createElement('span');
            icon.className = 'tree-icon';
            icon.textContent = entry.is_directory ? '📁' : this.getFileIcon(entry.name);
            item.appendChild(icon);

            const name = document.createElement('span');
            name.textContent = entry.name;
            item.appendChild(name);

            if (entry.is_directory) {
                item.addEventListener('click', async (e) => {
                    e.stopPropagation();
                    const arrowIcon = item.querySelector('.tree-arrow-icon');
                    if (this.expandedFolders.has(entry.path)) {
                        this.expandedFolders.delete(entry.path);
                        arrowIcon?.classList.remove('expanded');
                        const children = item.querySelector('.tree-children');
                        children?.remove();
                    } else {
                        this.expandedFolders.add(entry.path);
                        arrowIcon?.classList.add('expanded');
                        try {
                            const listing = await invoke<DirectoryListing>('list_directory', { path: entry.path });
                            const childContainer = document.createElement('div');
                            childContainer.className = 'tree-children';
                            this.renderFileTree(listing.entries);
                            item.appendChild(childContainer);
                        } catch (e) {
                            console.error('Failed to load directory:', e);
                        }
                    }
                });
            } else {
                item.addEventListener('click', () => {
                    this.openFile(entry.path);
                    document.querySelectorAll('.tree-item').forEach(t => t.classList.remove('active'));
                    item.classList.add('active');
                });
            }

            container.appendChild(item);
        }
    }

    private getFileIcon(filename: string): string {
        const ext = filename.split('.').pop()?.toLowerCase();
        const icons: Record<string, string> = {
            'rs': '🦀',
            'ts': '📘',
            'tsx': '⚛',
            'js': '📜',
            'jsx': '⚛',
            'json': '📋',
            'html': '🌐',
            'css': '🎨',
            'md': '📝',
            'toml': '⚙',
            'yaml': '📄',
            'yml': '📄',
            'sh': '🖥',
            'bash': '🖥',
            'png': '🖼',
            'jpg': '🖼',
            'jpeg': '🖼',
            'gif': '🖼',
            'svg': '🖼',
            'txt': '📄',
            'pdf': '📕',
            'zip': '📦',
            'tar': '📦',
            'gz': '📦',
        };
        return icons[ext || ''] || '📄';
    }

    private getLanguage(filename: string): string {
        const ext = filename.split('.').pop()?.toLowerCase();
        const langs: Record<string, string> = {
            'rs': 'rust',
            'ts': 'typescript',
            'tsx': 'typescript',
            'js': 'javascript',
            'jsx': 'javascript',
            'json': 'json',
            'html': 'html',
            'css': 'css',
            'scss': 'scss',
            'less': 'less',
            'md': 'markdown',
            'toml': 'toml',
            'yaml': 'yaml',
            'yml': 'yaml',
            'sh': 'shell',
            'bash': 'shell',
            'py': 'python',
            'rb': 'ruby',
            'go': 'go',
            'java': 'java',
            'c': 'c',
            'cpp': 'cpp',
            'h': 'c',
            'hpp': 'cpp',
            'cs': 'csharp',
            'swift': 'swift',
            'kt': 'kotlin',
            'rs': 'rust',
        };
        return langs[ext || ''] || 'plaintext';
    }

    private async openFile(path: string): Promise<void> {
        try {
            const content = await invoke<string>('read_file', { path });
            const name = path.split('/').pop() || path;
            const language = this.getLanguage(name);

            const existingTab = this.tabs.find(t => t.path === path);
            if (existingTab) {
                this.activateTab(existingTab.id);
                return;
            }

            if (this.editor) {
                const model = monaco.editor.createModel(content, language);
                this.editor.setModel(model);
            }

            const tab: Tab = {
                id: `file-${Date.now()}`,
                path,
                name,
                isModified: false,
                language,
            };

            this.tabs.push(tab);
            this.activeTabId = tab.id;
            this.createTabUI(tab);
            this.updateStatusBar(language);

            document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
            const tabEl = document.querySelector(`[data-tab-id="${tab.id}"]`);
            tabEl?.classList.add('active');

        } catch (e) {
            console.error('Failed to open file:', e);
        }
    }

    private createTabUI(tab: Tab): void {
        const tabsLeft = document.getElementById('tabsLeft');
        if (!tabsLeft) return;

        const tabEl = document.createElement('div');
        tabEl.className = 'tab active';
        tabEl.dataset.tabId = tab.id;

        const icon = document.createElement('span');
        icon.className = 'tree-icon';
        icon.textContent = this.getFileIcon(tab.name);
        tabEl.appendChild(icon);

        const name = document.createElement('span');
        name.textContent = tab.name;
        tabEl.appendChild(name);

        const closeBtn = document.createElement('span');
        closeBtn.className = 'tab-close';
        closeBtn.textContent = '×';
        closeBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            this.closeTab(tab.id);
        });
        tabEl.appendChild(closeBtn);

        tabEl.addEventListener('click', () => this.activateTab(tab.id));

        tabsLeft.appendChild(tabEl);
    }

    private updateTabUI(tab: Tab): void {
        const tabEl = document.querySelector(`[data-tab-id="${tab.id}"]`);
        if (!tabEl) return;

        const existingDot = tabEl.querySelector('.modified-dot');
        if (tab.isModified && !existingDot) {
            const dot = document.createElement('span');
            dot.className = 'modified-dot';
            dot.style.cssText = 'width:6px;height:6px;background:#f59e0b;border-radius:50%;margin-left:4px;';
            tabEl.appendChild(dot);
        } else if (!tab.isModified && existingDot) {
            existingDot.remove();
        }
    }

    private closeTab(tabId: string): void {
        const tabIndex = this.tabs.findIndex(t => t.id === tabId);
        if (tabIndex === -1) return;

        const tab = this.tabs[tabIndex];

        if (tab.isModified) {
            // TODO: Show confirmation dialog
        }

        this.tabs.splice(tabIndex, 1);

        const tabEl = document.querySelector(`[data-tab-id="${tabId}"]`);
        tabEl?.remove();

        if (this.activeTabId === tabId) {
            if (this.tabs.length > 0) {
                const newTab = this.tabs[Math.max(0, tabIndex - 1)];
                this.activateTab(newTab.id);
            } else {
                this.activeTabId = null;
                this.editor?.setValue('');
                this.updateStatusBar('Plain Text');
            }
        }
    }

    private activateTab(tabId: string): void {
        const tab = this.tabs.find(t => t.id === tabId);
        if (!tab) return;

        this.activeTabId = tabId;

        document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
        const tabEl = document.querySelector(`[data-tab-id="${tabId}"]`);
        tabEl?.classList.add('active');

        this.loadFileContent(tab.path, tab.language);
    }

    private async loadFileContent(path: string, language: string): Promise<void> {
        try {
            const content = await invoke<string>('read_file', { path });
            if (this.editor) {
                const model = monaco.editor.createModel(content, language);
                this.editor.setModel(model);
            }
        } catch (e) {
            console.error('Failed to load file content:', e);
        }
    }

    private updateStatusBar(language: string): void {
        const langStatus = document.getElementById('statusLanguage');
        if (langStatus) {
            langStatus.textContent = language.charAt(0).toUpperCase() + language.slice(1);
        }
    }

    private async showSearchPanel(): Promise<void> {
        // TODO: Implement search panel
        console.log('Search panel requested');
    }
}

document.addEventListener('DOMContentLoaded', () => {
    new CodniaEditor();
});

declare global {
    interface Window {
        __TAURI__?: {
            core: {
                invoke: (cmd: string, args?: Record<string, unknown>) => Promise<unknown>;
            };
        };
    }
}