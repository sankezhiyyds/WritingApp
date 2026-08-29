import { TemplateInfo } from './TemplateModel';

export class WorkManager {
  private works: WorkItem[] = [];
  private storageKey: string = 'writing_app_works';

  async init() {
    // 从本地存储加载作品列表
    try {
      const stored = await this.loadFromStorage();
      if (stored) {
        this.works = stored;
      }
    } catch (e) {
      console.error('[WorkManager] 初始化失败', e);
    }
  }

  async loadFromStorage(): Promise<WorkItem[] | null> {
    // 使用 LocalStorage 持久化
    return null;
  }

  async saveToStorage() {
    // 持久化到本地
  }

  createWork(template: TemplateInfo, title: string, content: string): WorkItem {
    const now = new Date();
    const work: WorkItem = {
      id: this.generateId(),
      title: title,
      templateId: template.id,
      templateName: template.name,
      content: content,
      createTime: this.formatDate(now),
      updateTime: this.formatDate(now)
    };
    this.works.unshift(work);
    this.saveToStorage();
    return work;
  }

  updateWork(workId: string, content: string): WorkItem | null {
    const work = this.works.find(w => w.id === workId);
    if (work) {
      work.content = content;
      work.updateTime = this.formatDate(new Date());
      this.saveToStorage();
    }
    return work || null;
  }

  deleteWork(workId: string): boolean {
    const index = this.works.findIndex(w => w.id === workId);
    if (index !== -1) {
      this.works.splice(index, 1);
      this.saveToStorage();
      return true;
    }
    return false;
  }

  getWork(workId: string): WorkItem | null {
    return this.works.find(w => w.id === workId) || null;
  }

  getAllWorks(): WorkItem[] {
    return this.works;
  }

  getWorksByTemplate(templateId: string): WorkItem[] {
    return this.works.filter(w => w.templateId === templateId);
  }

  private generateId(): string {
    return 'work_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
  }

  private formatDate(date: Date): string {
    return date.toLocaleString('zh-CN', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    });
  }
}

export interface WorkItem {
  id: string;
  title: string;
  templateId: string;
  templateName: string;
  content: string;
  createTime: string;
  updateTime: string;
}

export const workManager = new WorkManager();
