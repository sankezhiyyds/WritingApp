export interface TemplateInfo {
  id: string;
  name: string;
  icon: string;
  desc: string;
  category: string;
  color: string;
  fields: TemplateField[];
  format: string;
  tips: string[];
}

export interface TemplateField {
  key: string;
  label: string;
  type: 'text' | 'textarea' | 'select' | 'number';
  required: boolean;
  placeholder: string;
  options?: string[];
}

export const templateList: TemplateInfo[] = [
  {
    id: 'short_drama',
    name: '短剧剧本',
    icon: '🎬',
    desc: '竖屏短剧，快节奏强冲突',
    category: '剧本类',
    color: '#FF2D55',
    fields: [
      { key: 'title', label: '剧名', type: 'text', required: true, placeholder: '请输入剧名' },
      { key: 'genre', label: '类型', type: 'select', required: true, placeholder: '选择类型', options: ['甜宠', '虐恋', '复仇', '豪门', '职场'] },
      { key: 'protagonist', label: '主角设定', type: 'textarea', required: true, placeholder: '用3-5句话描述主角的核心特征和行为模式' },
      { key: 'conflict', label: '核心冲突', type: 'textarea', required: true, placeholder: '主角面临的主要矛盾是什么？' },
      { key: 'episodes', label: '集数', type: 'number', required: true, placeholder: '总集数' },
      { key: 'outline', label: '剧情大纲', type: 'textarea', required: false, placeholder: '整体故事走向...' }
    ],
    format: `【剧名】{title}
【类型】{genre}
【集数】{episodes}集

【主角】
{protagonist}

【核心冲突】
{conflict}

【剧情大纲】
{outline}`,
    tips: [
      '每集控制在1-3分钟，节奏要快',
      '开头3秒必须有钩子（悬念/冲突/反差）',
      '用具体动作推动剧情，避免旁白说明',
      '场景转换要简洁，一集1-3个场景',
      '结尾必须留悬念，让观众想看下一集'
    ]
  },
  {
    id: 'manzai',
    name: '漫才',
    icon: '🎭',
    desc: '日式组合喜剧，装傻与吐槽',
    category: '喜剧类',
    color: '#FF6B35',
    fields: [
      { key: 'boke', label: '装傻角色', type: 'textarea', required: true, placeholder: '装傻者的性格特点和经典失误' },
      { key: 'tsukkomi', label: '吐槽角色', type: 'textarea', required: true, placeholder: '吐槽者的反应模式和经典台词' },
      { key: 'theme', label: '主题', type: 'text', required: true, placeholder: '表演围绕什么话题展开' },
      { key: 'jokes', label: '笑点清单', type: 'textarea', required: false, placeholder: '预设的笑点或意外情况...' }
    ],
    format: `【漫才：{theme}】

【装傻】{boke}
【吐槽】{tsukkomi}

【对话框架】
（装傻给出荒谬观点或错误行为）
→（吐槽进行精准打击）
→（装傻继续升级荒谬）
→（吐槽终极反击）`,
    tips: [
      '装傻要够"傻"，吐槽要够"准"',
      '笑点来自预期违背，而非刻意搞笑',
      '节奏要快，不留空白',
      '用具体行为制造笑料，不用抽象形容词'
    ]
  },
  {
    id: 'hero_journey',
    name: '英雄之旅',
    icon: '⚔️',
    desc: '经典叙事结构，启程-启蒙-归来',
    category: '叙事类',
    color: '#10B981',
    fields: [
      { key: 'hero', label: '主角设定', type: 'textarea', required: true, placeholder: '普通人的初始状态和内在缺陷' },
      { key: 'call', label: '冒险召唤', type: 'textarea', required: true, placeholder: '什么事件打破了主角的平静生活？' },
      { key: 'mentor', label: '导师/帮手', type: 'textarea', required: false, placeholder: '谁帮助主角踏上旅程？' },
      { key: 'trials', label: '考验与敌人', type: 'textarea', required: true, placeholder: '主角面临的主要挑战和对手' },
      { key: 'ultimate', label: '终极考验', type: 'textarea', required: true, placeholder: '最艰难的挑战是什么？' },
      { key: 'return', label: '归来与变化', type: 'textarea', required: true, placeholder: '主角如何带着收获回归？' }
    ],
    format: `【英雄之旅】

【第一幕：启程】
普通世界：{hero}
冒险召唤：{call}
拒绝召唤：（主角犹豫/逃避的原因）
遇见导师：{mentor}
跨越门槛：（决定踏上旅程）

【第二幕：启蒙】
考验、伙伴、敌人：{trials}
接近洞穴：（面临最大挑战前）
终极考验：{ultimate}
获得报酬：（主角的收获/顿悟）

【第三幕：归来】
归途：（带着收获返回）
两个世界的统一：{return}`,
    tips: [
      '主角必须有明显的内在缺陷需要成长',
      '每个考验都要让主角更接近真相',
      '终极考验应该是内外双重危机',
      '归来后的变化要具体可见'
    ]
  },
  {
    id: 'emotional_tension',
    name: '情感拉扯',
    icon: '💫',
    desc: '两人关系，推拉之间的情感张力',
    category: '叙事类',
    color: '#A855F7',
    fields: [
      { key: 'person_a', label: '角色A', type: 'textarea', required: true, placeholder: '用具体行为和反应描述这个人的特点' },
      { key: 'person_b', label: '角色B', type: 'textarea', required: true, placeholder: '用具体行为和反应描述这个人的特点' },
      { key: 'core_desire', label: '各自渴望', type: 'textarea', required: true, placeholder: 'A想要什么？B想要什么？' },
      { key: 'obstacle', label: '阻碍', type: 'textarea', required: true, placeholder: '什么让他们无法在一起/分开？' },
      { key: 'turning_point', label: '关键转折', type: 'textarea', required: true, placeholder: '关系发生转变的具体事件' }
    ],
    format: `【情感拉扯】

【角色A】{person_a}
【角色B】{person_b}

【渴望】
{core_desire}

【阻碍】{obstacle}

【关键转折】{turning_point}

【拉扯节奏】
靠近 → 推开 → 再靠近 → 真相 → 抉择`,
    tips: [
      '用具体动作表达情感，不说"他很爱她"',
      '推拉要有节奏：靠近-推开的幅度逐渐加大',
      '让读者猜测"他们到底会不会在一起"',
      '转折要具体，不要只说"感情变了"'
    ]
  },
  {
    id: 'mystery',
    name: '悬疑推理',
    icon: '🔍',
    desc: '谜题-线索-反转-真相',
    category: '剧本类',
    color: '#3B82F6',
    fields: [
      { key: 'crime', label: '案件设定', type: 'textarea', required: true, placeholder: '发生了什么？受害者是谁？' },
      { key: 'detective', label: '侦探/主角', type: 'textarea', required: true, placeholder: '如何发现案件？有什么独特能力？' },
      { key: 'suspects', label: '嫌疑人清单', type: 'textarea', required: true, placeholder: '列出所有嫌疑人及其动机' },
      { key: 'clues', label: '线索设计', type: 'textarea', required: true, placeholder: '真假线索分别是什么？' },
      { key: 'twist', label: '反转', type: 'textarea', required: true, placeholder: '真相如何出人意料？' }
    ],
    format: `【悬疑推理】

【案件】{crime}

【侦探】{detective}

【嫌疑人】
{suspects}

【线索】
关键线索：{clues}

【反转】{twist}

【真相】
（最终揭示）`,
    tips: [
      '线索要公平：读者有同等机会推理',
      '每个嫌疑人都要有合理动机',
      '反转要合理，不能凭空出现',
      '用具体物证代替口供推动剧情'
    ]
  },
  {
    id: 'sketch',
    name: '素描喜剧',
    icon: '✏️',
    desc: '单一前提的渐进式喜剧',
    category: '喜剧类',
    color: '#F59E0B',
    fields: [
      { key: 'premise', label: '前提', type: 'text', required: true, placeholder: '一个"如果...会怎样"的设定' },
      { key: 'characters', label: '角色', type: 'textarea', required: true, placeholder: '哪些角色在这个前提下行事？' },
      { key: 'escalation', label: '升级方向', type: 'textarea', required: true, placeholder: '喜剧效果如何一步步升级？' },
      { key: 'button', label: '结尾按钮', type: 'text', required: false, placeholder: '最后的笑点/收尾方式' }
    ],
    format: `【素描喜剧】

【前提】如果{premise}？

【角色】{characters}

【升级路径】
{escalation}

【结尾】{button}`,
    tips: [
      '前提是唯一的喜剧来源，不偏离',
      '每次升级要比上次更极端',
      '用重复+变化的技巧制造笑点',
      '结尾要干净利落'
    ]
  },
  {
    id: 'short_video',
    name: '短视频脚本',
    icon: '📱',
    desc: '15-60秒短视频的完整脚本',
    category: '剧本类',
    color: '#EC4899',
    fields: [
      { key: 'platform', label: '平台', type: 'select', required: true, placeholder: '选择平台', options: ['抖音', '快手', '视频号', 'B站'] },
      { key: 'duration', label: '时长', type: 'number', required: true, placeholder: '预计秒数' },
      { key: 'hook', label: '开场钩子', type: 'textarea', required: true, placeholder: '前3秒抓住观众的内容' },
      { key: 'content', label: '正文内容', type: 'textarea', required: true, placeholder: '主体内容描述' },
      { key: 'cta', label: '结尾引导', type: 'text', required: false, placeholder: '关注/评论/点赞引导' }
    ],
    format: `【短视频脚本】

【平台】{platform}
【时长】{duration}秒

【分镜脚本】
开场钩子：{hook}
正文内容：{content}
结尾引导：{cta}

【画面描述】
（镜头角度/景别/运镜）

【字幕/文案】
（屏幕文字）

【音效/BGM】
（背景音乐和音效提示）`,
    tips: [
      '前3秒决定生死，必须有强钩子',
      '节奏紧凑，每2-3秒一个信息点',
      '画面+字幕+声音三重刺激',
      '结尾引导要明确具体'
    ]
  },
  {
    id: 'script_murder',
    name: '剧本杀',
    icon: '🕵️',
    desc: '沉浸式推理游戏剧本',
    category: '剧本类',
    color: '#8B5CF6',
    fields: [
      { key: 'background', label: '背景设定', type: 'textarea', required: true, placeholder: '故事发生的时代和场景' },
      { key: 'characters', label: '角色名单', type: 'textarea', required: true, placeholder: '每个角色的身份和秘密' },
      { key: 'case', label: '案件', type: 'textarea', required: true, placeholder: '发生了什么事？' },
      { key: 'truth', label: '真相', type: 'textarea', required: true, placeholder: '完整的推理过程和真相' },
      { key: 'mechanics', label: '机制设计', type: 'textarea', required: false, placeholder: '特殊玩法/道具/时间线' }
    ],
    format: `【剧本杀】

【背景】{background}

【角色】
{characters}

【案件】{case}

【真相】{truth}

【机制】{mechanics}`,
    tips: [
      '每个角色都要有明确的动机和秘密',
      '线索要分层：公开线索→个人线索→隐藏线索',
      '真相要经得起推敲，不能漏洞百出',
      '机制设计要有创新，不要太老套'
    ]
  },
  {
    id: 'story_nucleus',
    name: '故事核',
    icon: '🥚',
    desc: '一个核心创意的完整展开',
    category: '叙事类',
    color: '#14B8A6',
    fields: [
      { key: 'core', label: '核心创意', type: 'textarea', required: true, placeholder: '一句话概括你的核心想法' },
      { key: 'protagonist', label: '主角', type: 'textarea', required: true, placeholder: '主角是谁？想要什么？' },
      { key: 'conflict', label: '核心冲突', type: 'textarea', required: true, placeholder: '什么在阻碍主角？' },
      { key: 'stake', label: '赌注', type: 'textarea', required: true, placeholder: '失败了会怎样？' },
      { key: 'resolution', label: '解决方向', type: 'textarea', required: false, placeholder: '可能的结局方向' }
    ],
    format: `【故事核】

【核心创意】{core}

【主角】{protagonist}

【核心冲突】{conflict}

【赌注】{stake}

【解决方向】{resolution}`,
    tips: [
      '核心创意要用一句话能说清楚',
      '赌注越大，故事越吸引人',
      '冲突要是内外结合的',
      '解决方向可以有多种可能'
    ]
  },
  {
    id: 'viral_formula',
    name: '爆款公式',
    icon: '🔥',
    desc: '可复制的内容爆款结构',
    category: '叙事类',
    color: '#EF4444',
    fields: [
      { key: 'topic', label: '主题', type: 'text', required: true, placeholder: '内容主题' },
      { key: 'hook_type', label: '钩子类型', type: 'select', required: true, placeholder: '选择开场方式', options: ['反差型', '悬念型', '提问型', '共鸣型', '好奇型'] },
      { key: 'emotional_curve', label: '情绪曲线', type: 'textarea', required: true, placeholder: '内容的情绪起伏节奏' },
      { key: 'core_message', label: '核心信息', type: 'textarea', required: true, placeholder: '观众看完应该记住什么？' },
      { key: 'share_trigger', label: '分享触发点', type: 'text', required: true, placeholder: '观众为什么会分享？' }
    ],
    format: `【爆款公式】

【主题】{topic}

【开场钩子】{hook_type}
（具体内容：___）

【情绪曲线】
{emotional_curve}

【核心信息】{core_message}

【分享触发】{share_trigger}`,
    tips: [
      '钩子要在前3秒内建立预期',
      '情绪要有起伏，不能平铺直叙',
      '核心信息要简单好记',
      '分享触发点要具体明确'
    ]
  },
  {
    id: 'three_act',
    name: '三幕式结构',
    icon: '📖',
    desc: '经典电影/小说叙事框架',
    category: '叙事类',
    color: '#6366F1',
    fields: [
      { key: 'act1_setup', label: '第一幕：铺垫', type: 'textarea', required: true, placeholder: '世界观、主角日常、激励事件' },
      { key: 'act1_turn', label: '第一幕转折点', type: 'textarea', required: true, placeholder: '主角决定踏上旅程的契机' },
      { key: 'act2_confront', label: '第二幕：对抗', type: 'textarea', required: true, placeholder: '中间高潮、一切归零时刻' },
      { key: 'act3_resolve', label: '第三幕：解决', type: 'textarea', required: true, placeholder: '最终对决、结局' }
    ],
    format: `【三幕式结构】

【第一幕：铺垫】（25%）
{act1_setup}
转折点：{act1_turn}

【第二幕：对抗】（50%）
{act2_confront}

【第三幕：解决】（25%）
{act3_resolve}`,
    tips: [
      '第一幕要快速建立世界观和主角',
      '第二幕要不断增加阻力和转折',
      '中点（25%处）要有重大事件',
      '第三幕要解决所有伏笔'
    ]
  },
  {
    id: 'five_act',
    name: '五幕剧',
    icon: '🎪',
    desc: '莎士比亚式戏剧结构',
    category: '剧本类',
    color: '#0EA5E9',
    fields: [
      { key: 'exposition', label: '铺垫', type: 'textarea', required: true, placeholder: '背景介绍和人物关系' },
      { key: 'rising', label: '上升行动', type: 'textarea', required: true, placeholder: '冲突逐步升级' },
      { key: 'climax', label: '高潮', type: 'textarea', required: true, placeholder: '戏剧性转折点' },
      { key: 'falling', label: '下降行动', type: 'textarea', required: true, placeholder: '后果展开' },
      { key: 'resolution', label: '结局', type: 'textarea', required: true, placeholder: '冲突解决' }
    ],
    format: `【五幕剧】

【第一幕：铺垫】{exposition}
【第二幕：上升行动】{rising}
【第三幕：高潮】{climax}
【第四幕：下降行动】{falling}
【第五幕：结局】{resolution}`,
    tips: [
      '高潮必须是不可逆转的转折点',
      '每幕之间要有清晰的逻辑递进',
      '结局要回应开头的伏笔',
      '五幕节奏比三幕更细腻'
    ]
  },
  {
    id: 'monologue',
    name: '戏剧独白',
    icon: '🎤',
    desc: '单人长篇独白，内心外化',
    category: '剧本类',
    color: '#84CC16',
    fields: [
      { key: 'speaker', label: '说话者', type: 'textarea', required: true, placeholder: '谁在独白？在什么情境下？' },
      { key: 'audience', label: '听众', type: 'text', required: false, placeholder: '对谁说话？（观众/自己/某人）' },
      { key: 'theme', label: '主题', type: 'text', required: true, placeholder: '独白的核心议题' },
      { key: 'arc', label: '情绪弧线', type: 'textarea', required: true, placeholder: '从什么情绪开始，到什么情绪结束？' }
    ],
    format: `【戏剧独白】

【说话者】{speaker}
【听众】{audience}
【主题】{theme}

【情绪弧线】{arc}

【独白正文】
（开始）
...
（结束）`,
    tips: [
      '独白要有明确的倾诉对象',
      '情绪变化要有层次感',
      '用具体意象代替抽象概念',
      '结尾要有力量感或留白'
    ]
  },
  {
    id: 'absurdist',
    name: '荒诞派剧本',
    icon: '🌀',
    desc: '反逻辑、反理性的实验戏剧',
    category: '剧本类',
    color: '#F97316',
    fields: [
      { key: 'setting', label: '场景设定', type: 'textarea', required: true, placeholder: '一个荒诞的空间' },
      { key: 'characters', label: '角色', type: 'textarea', required: true, placeholder: '角色如何体现荒诞性？' },
      { key: 'logic', label: '荒诞逻辑', type: 'textarea', required: true, placeholder: '什么是不合理的？为什么合理？' },
      { key: 'ending', label: '结局方式', type: 'select', required: true, placeholder: '选择结局风格', options: ['循环', '开放', '突然中断', '无声无息'] }
    ],
    format: `【荒诞派剧本】

【场景】{setting}

【角色】{characters}

【荒诞逻辑】{logic}

【结局】{ending}`,
    tips: [
      '荒诞要源于现实的扭曲，不是胡乱',
      '用重复和等待制造张力',
      '对话要有逻辑断裂感',
      '结局可以是无意义的延续'
    ]
  },
  {
    id: 'comedy_chain',
    name: '喜剧冲突链',
    icon: '⛓️',
    desc: '因果连锁的喜剧推进',
    category: '喜剧类',
    color: '#22C55E',
    fields: [
      { key: 'first_event', label: '起始事件', type: 'textarea', required: true, placeholder: '引发连锁的第一件事' },
      { key: 'chain', label: '冲突链', type: 'textarea', required: true, placeholder: '每个事件如何导致下一个？' },
      { key: 'climax', label: '高潮点', type: 'textarea', required: true, placeholder: '连锁反应的最高峰' },
      { key: 'resolution', label: '收束', type: 'textarea', required: true, placeholder: '如何让连锁停止？' }
    ],
    format: `【喜剧冲突链】

【起始】{first_event}

【连锁】
{chain}

【高潮】{climax}

【收束】{resolution}`,
    tips: [
      '每个事件必须是前一个的结果',
      '喜剧效果来自因果的荒谬放大',
      '收束要让观众释然',
      '可以设置意外的打破者'
    ]
  },
  {
    id: 'sitcom',
    name: '情景喜剧',
    icon: '🏠',
    desc: '固定场景的多人物喜剧',
    category: '喜剧类',
    color: '#E879F9',
    fields: [
      { key: 'setting', label: '场景', type: 'textarea', required: true, placeholder: '主要发生地点（家/办公室/咖啡馆等）' },
      { key: 'characters', label: '角色阵容', type: 'textarea', required: true, placeholder: '每个角色的性格和关系' },
      { key: 'conflict_source', label: '冲突来源', type: 'textarea', required: true, placeholder: '喜剧冲突从何而来？' },
      { key: 'episode_structure', label: '单集结构', type: 'textarea', required: false, placeholder: '典型的一集怎么展开？' }
    ],
    format: `【情景喜剧】

【场景】{setting}

【角色】{characters}

【冲突来源】{conflict_source}

【单集结构】{episode_structure}

【示例场景】
（一个典型的喜剧场景示例）`,
    tips: [
      '场景要固定但有足够空间制造冲突',
      '角色性格要鲜明，关系要有张力',
      '冲突来自性格碰撞，不是外部事件',
      '每集结尾要有温馨的回归'
    ]
  },
  {
    id: 'inspiration_note',
    name: '灵感笔记',
    icon: '💡',
    desc: '快速记录创作灵感',
    category: '灵感类',
    color: '#FBBF24',
    fields: [
      { key: 'title', label: '灵感标题', type: 'text', required: true, placeholder: '给这个灵感起个名字' },
      { key: 'category', label: '分类', type: 'select', required: false, placeholder: '选择分类', options: ['人物', '情节', '场景', '对话', '主题', '其他'] },
      { key: 'content', label: '灵感内容', type: 'textarea', required: true, placeholder: '详细描述你的灵感...' },
      { key: 'tags', label: '标签', type: 'text', required: false, placeholder: '用逗号分隔多个标签' }
    ],
    format: `【灵感笔记】

【标题】{title}
【分类】{category}
【标签】{tags}

【内容】
{content}`,
    tips: [
      '灵感稍纵即逝，快速记录核心想法',
      '不需要完整，关键词和片段也有价值',
      '定期回顾灵感笔记，发现创作素材',
      '可以用标签系统化管理灵感'
    ]
  },
  {
    id: 'ad_copy',
    name: '广告文案',
    icon: '📢',
    desc: '产品/服务广告文案',
    category: '广告类',
    color: '#EC4899',
    fields: [
      { key: 'product', label: '产品/服务', type: 'text', required: true, placeholder: '推广什么产品或服务？' },
      { key: 'target', label: '目标受众', type: 'textarea', required: true, placeholder: '面向什么人群？他们的痛点是什么？' },
      { key: 'usp', label: '独特卖点', type: 'textarea', required: true, placeholder: '产品最独特的优势是什么？' },
      { key: 'tone', label: '文案调性', type: 'select', required: false, placeholder: '选择文案风格', options: ['专业', '幽默', '温情', '激励', '紧迫'] },
      { key: 'cta', label: '行动号召', type: 'text', required: false, placeholder: '希望用户做什么？（立即购买/了解更多等）' }
    ],
    format: `【广告文案】

【产品】{product}
【目标受众】{target}
【独特卖点】{usp}
【文案调性】{tone}

【主标题】
（吸引注意力的标题）

【副标题】
（补充说明核心卖点）

【正文】
（详细阐述产品价值）

【行动号召】
{cta}`,
    tips: [
      '标题要在3秒内抓住注意力',
      '突出用户收益，而非产品功能',
      '用具体数字和案例增强说服力',
      '行动号召要明确且紧迫'
    ]
  }
];
