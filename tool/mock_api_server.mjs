#!/usr/bin/env node
/**
 * Local development server: serves the built Flutter web app and a small
 * in-memory imitation of the Sabt Nest API. Never talks to production and
 * never needs real credentials.
 *
 *   flutter build web --dart-define=API_BASE_URL=http://localhost:8787/api \
 *                     --dart-define=WS_BASE_URL=http://localhost:8787
 *   node tool/mock_api_server.mjs
 *
 * Open http://localhost:8787 and sign in with any login/password.
 */
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const WEB_ROOT = path.resolve(__dirname, '..', 'build', 'web');
const PORT = Number(process.env.PORT || 8787);

const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Dushanbe' }).format(new Date());
const day = (offset) => {
  const d = new Date(`${today}T12:00:00Z`);
  d.setUTCDate(d.getUTCDate() + offset);
  return d.toISOString().slice(0, 10);
};
const at = (offset, hour, minute = 0) =>
  `${day(offset)}T${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}:00+05:00`;
const minutesAgo = (minutes) => new Date(Date.now() - minutes * 60000).toISOString();

const user = {
  id: 'u-founder',
  name: 'Фарход Сафаров',
  email: 'farhod@webbrand.tj',
  role: 'founder',
  secondaryRole: null,
  avatar: null,
  isActive: true,
  isSubAdmin: false,
  isStoryMaker: true,
  extraPermissions: ['calendar.view', 'calendar.create'],
  deniedPermissions: [],
  position: 'Основатель',
  department: 'Управление',
  twoFactorEnabled: false,
  themeColor: null,
};

const people = [
  { id: 'u-founder', name: 'Фарход Сафаров', avatar: null, position: 'Основатель' },
  { id: 'u-1', name: 'Мадина Каримова', avatar: null, position: 'SMM специалист' },
  { id: 'u-2', name: 'Рустам Назаров', avatar: null, position: 'Дизайнер' },
  { id: 'u-3', name: 'Далер Холов', avatar: null, position: 'Видеограф' },
];
const person = (id) => people.find((p) => p.id === id) || people[0];

const projects = [
  {
    id: 'p-1',
    name: 'Mila Coffee',
    description: 'Сеть кофеен в Душанбе: контент, рилсы и запуск сезонных меню.',
    projectType: 'SMM',
    status: 'in_progress',
    progress: 64,
    startDate: at(-120, 10),
    endDate: null,
    manager: person('u-founder'),
    salesManager: person('u-3'),
    members: [people[1], people[2], people[3]],
    membersCount: 3,
    taskCount: 18,
    doneTaskCount: 12,
    isArchived: false,
    hasActiveAd: true,
    lastActivityAt: minutesAgo(35),
    createdAt: at(-120, 10),
    tariffNameSnapshot: 'SMM Growth',
    monthlyFee: 8500,
    paymentStatus: 'paid',
    nextPaymentDate: at(6, 10),
    billingType: 'monthly',
    smmData: {
      normReels: 8,
      normPosts: 12,
      storiesPerMonth: 90,
      storiesArchived: false,
      smmSpecialistIds: ['u-1'],
    },
  },
  {
    id: 'p-2',
    name: 'Dushanbe Grand Hotel',
    description: 'Премиальный отель: имиджевый контент и сторис каждый день.',
    projectType: 'SMM',
    status: 'in_progress',
    progress: 41,
    startDate: at(-60, 10),
    endDate: null,
    manager: person('u-1'),
    salesManager: null,
    members: [people[1], people[2]],
    membersCount: 2,
    taskCount: 11,
    doneTaskCount: 5,
    isArchived: false,
    hasActiveAd: false,
    lastActivityAt: minutesAgo(180),
    createdAt: at(-60, 10),
    tariffNameSnapshot: 'SMM Premium',
    monthlyFee: 14000,
    paymentStatus: 'pending',
    nextPaymentDate: at(2, 10),
    billingType: 'monthly',
    smmData: {
      normReels: 6,
      normPosts: 10,
      storiesPerMonth: 120,
      storiesArchived: false,
      smmSpecialistIds: ['u-1'],
    },
  },
  {
    id: 'p-3',
    name: 'Sabt CRM',
    description: 'Внутренний продукт: мобильное приложение и веб-кабинет.',
    projectType: 'CRM система',
    status: 'planning',
    progress: 18,
    startDate: at(-20, 10),
    endDate: null,
    manager: person('u-founder'),
    salesManager: null,
    members: [people[0], people[2]],
    membersCount: 2,
    taskCount: 7,
    doneTaskCount: 2,
    isArchived: false,
    hasActiveAd: false,
    lastActivityAt: minutesAgo(1440),
    createdAt: at(-20, 10),
    tariffNameSnapshot: null,
    monthlyFee: null,
    paymentStatus: null,
    nextPaymentDate: null,
    billingType: null,
    smmData: null,
  },
];

const tasks = [
  {
    id: 't-1',
    title: 'Согласовать сентябрьский контент-план с клиентом',
    status: 'in_progress',
    priority: 'high',
    description:
        'Собрать финальную сетку рилсов и постов, отправить клиенту на согласование до вечера. Учесть новые позиции меню.',
    project: projects[0],
    assignee: person('u-1'),
    createdBy: person('u-founder'),
    deadline: at(-1, 18),
    startDate: at(-3, 10),
    completedAt: null,
    createdAt: at(-4, 9),
    progress: 60,
    scope: 'business',
    kind: 'task',
    fromFounder: true,
    tags: ['контент', 'клиент'],
    acceptanceCriteria: [
      { id: 'a-1', text: 'Сетка на 8 рилсов и 12 постов', done: true, doneAt: at(-2, 12) },
      { id: 'a-2', text: 'Подписи и CTA для каждой публикации', done: false },
      { id: 'a-3', text: 'Клиент подтвердил в переписке', done: false },
    ],
    assignees: [
      { userId: 'u-1', isDone: false, position: 0, note: null, user: people[1] },
      { userId: 'u-2', isDone: true, position: 1, note: 'Макеты готовы', user: people[2] },
    ],
  },
  {
    id: 't-2',
    title: 'Снять 3 рилса для Mila Coffee',
    status: 'new',
    priority: 'critical',
    description: 'Локация: флагманская кофейня на Рудаки. Реквизит и раскадровка в файлах задачи.',
    project: projects[0],
    assignee: person('u-3'),
    createdBy: person('u-founder'),
    deadline: at(0, 16, 30),
    startDate: null,
    completedAt: null,
    createdAt: at(-1, 11),
    progress: 0,
    scope: 'business',
    kind: 'task',
    fromFounder: false,
    tags: ['съёмка', 'рилс'],
    acceptanceCriteria: [],
    assignees: [
      { userId: 'u-3', isDone: false, position: 0, note: null, user: people[3] },
    ],
  },
  {
    id: 't-3',
    title: 'Обновить визуал сторис отеля',
    status: 'in_progress',
    priority: 'medium',
    description: 'Новая серия шаблонов под осенний сезон.',
    project: projects[1],
    assignee: person('u-2'),
    createdBy: person('u-1'),
    deadline: at(2, 18),
    startDate: at(-1, 10),
    completedAt: null,
    createdAt: at(-2, 15),
    progress: 40,
    scope: 'business',
    kind: 'task',
    fromFounder: false,
    tags: ['дизайн'],
    acceptanceCriteria: [],
    assignees: [
      { userId: 'u-2', isDone: false, position: 0, note: null, user: people[2] },
    ],
  },
  {
    id: 't-4',
    title: 'Встреча с клиентом Dushanbe Grand Hotel',
    status: 'new',
    priority: 'high',
    description: 'Обсудить результаты месяца и продление тарифа.',
    project: projects[1],
    assignee: person('u-founder'),
    createdBy: person('u-1'),
    deadline: at(0, 14),
    startDate: null,
    completedAt: null,
    createdAt: at(-1, 9),
    progress: 0,
    scope: 'business',
    kind: 'meeting',
    location: 'Zoom',
    fromFounder: false,
    tags: [],
    acceptanceCriteria: [],
    assignees: [
      { userId: 'u-founder', isDone: false, position: 0, note: null, user: people[0] },
    ],
  },
  {
    id: 't-5',
    title: 'Подготовить отчёт по охватам за месяц',
    status: 'done',
    priority: 'medium',
    description: 'Собрать статистику из Instagram и Meta Ads.',
    project: projects[0],
    assignee: person('u-1'),
    createdBy: person('u-founder'),
    deadline: at(-2, 18),
    startDate: at(-5, 10),
    completedAt: at(-2, 17),
    createdAt: at(-6, 9),
    progress: 100,
    scope: 'business',
    kind: 'task',
    fromFounder: false,
    tags: ['аналитика'],
    acceptanceCriteria: [],
    assignees: [
      { userId: 'u-1', isDone: true, position: 0, note: null, user: people[1] },
    ],
  },
  {
    id: 't-6',
    title: 'Проверить тексты для лендинга Sabt',
    status: 'new',
    priority: 'low',
    description: 'Вычитать блок с тарифами и FAQ.',
    project: projects[2],
    assignee: person('u-founder'),
    createdBy: person('u-founder'),
    deadline: at(4, 12),
    startDate: null,
    completedAt: null,
    createdAt: at(-1, 18),
    progress: 0,
    scope: 'personal',
    kind: 'task',
    fromFounder: false,
    tags: [],
    acceptanceCriteria: [],
    assignees: [],
  },
];

const smmProjects = projects
  .filter((p) => p.projectType === 'SMM')
  .map((p) => ({
    id: p.id,
    name: p.name,
    startDate: p.startDate,
    endDate: p.endDate,
    storiesArchived: false,
    isArchived: false,
    mine: true,
    specialistIds: p.smmData?.smmSpecialistIds || [],
    ...p.smmData,
  }));

const smmEvents = [
  {
    id: 'e-1',
    kind: 'publication',
    itemId: 'ci-1',
    date: at(0, 0),
    time: '11:00',
    contentType: 'reel',
    projectId: 'p-1',
    projectName: 'Mila Coffee',
    topic: 'Осеннее меню: латте с тыквой',
    status: 'in_production',
    assigneeId: 'u-1',
    durationMin: 60,
    count: 0,
    taskId: 't-2',
  },
  {
    id: 'e-2',
    kind: 'shoot',
    itemId: 'ci-2',
    date: at(0, 0),
    time: '14:30',
    contentType: 'design',
    projectId: 'p-2',
    projectName: 'Dushanbe Grand Hotel',
    topic: 'Шаблон сторис: осенний уикенд',
    prepStage: 'design',
    parentKind: 'post',
    status: 'preparing',
    assigneeId: 'u-2',
    durationMin: 90,
    count: 0,
  },
  {
    id: 'e-3',
    kind: 'publication',
    itemId: 'ci-3',
    date: at(0, 0),
    time: '18:00',
    contentType: 'story',
    projectId: 'p-1',
    projectName: 'Mila Coffee',
    topic: 'Сторис: закулисье кофейни',
    status: 'planned',
    assigneeId: 'u-1',
    count: 5,
  },
  {
    id: 'e-4',
    kind: 'publication',
    itemId: 'ci-4',
    date: at(1, 0),
    time: '10:00',
    contentType: 'post',
    projectId: 'p-2',
    projectName: 'Dushanbe Grand Hotel',
    topic: 'Карусель: 5 причин остановиться у нас',
    status: 'planned',
    assigneeId: 'u-2',
  },
  {
    id: 'e-5',
    kind: 'publication',
    itemId: 'ci-5',
    date: at(3, 0),
    time: '12:00',
    contentType: 'reel',
    projectId: 'p-1',
    projectName: 'Mila Coffee',
    topic: 'Рилс: бариста рекомендует',
    status: 'planned',
    assigneeId: 'u-1',
  },
];

const backlog = [
  {
    id: 'b-1',
    kind: 'publication',
    itemId: 'ci-b1',
    contentType: 'reel',
    projectId: 'p-1',
    projectName: 'Mila Coffee',
    topic: 'Рилс: новый десерт',
    scriptText: 'Хук → крупный план → реакция гостя → CTA.',
  },
  {
    id: 'b-2',
    kind: 'publication',
    itemId: 'ci-b2',
    contentType: 'post',
    projectId: 'p-2',
    projectName: 'Dushanbe Grand Hotel',
    topic: 'Пост: спа-программа',
  },
];

const employees = [
  {
    id: 'emp-1',
    fullName: 'Мадина Каримова',
    position: 'SMM специалист',
    department: 'SMM',
    email: 'madina@webbrand.tj',
    phone: '+992 93 555 11 22',
    telegram: '@madina',
    instagram: '@madina.k',
    status: 'active',
    avatar: null,
    isStoryMaker: true,
    user: { id: 'u-1', name: 'Мадина Каримова', role: 'smm_specialist', email: 'madina@webbrand.tj' },
    tasksCompleted: 126,
    tasksOverdue: 3,
    tasksReturned: 2,
    activityScore: 92,
    hireDate: at(-420, 10),
    lastActiveAt: minutesAgo(12),
    bio: 'Отвечает за контент Mila Coffee и сторис отеля.',
  },
  {
    id: 'emp-2',
    fullName: 'Рустам Назаров',
    position: 'Дизайнер',
    department: 'Дизайн',
    email: 'rustam@webbrand.tj',
    phone: '+992 92 700 44 55',
    telegram: '@rustam',
    status: 'active',
    avatar: null,
    user: { id: 'u-2', name: 'Рустам Назаров', role: 'designer' },
    tasksCompleted: 84,
    tasksOverdue: 1,
    tasksReturned: 4,
    activityScore: 78,
    hireDate: at(-300, 10),
    lastActiveAt: minutesAgo(55),
  },
  {
    id: 'emp-3',
    fullName: 'Далер Холов',
    position: 'Видеограф',
    department: 'Продакшн',
    email: 'daler@webbrand.tj',
    phone: '+992 88 900 33 21',
    telegram: '@daler',
    status: 'active',
    avatar: null,
    user: { id: 'u-3', name: 'Далер Холов', role: 'videographer' },
    tasksCompleted: 63,
    tasksOverdue: 0,
    tasksReturned: 1,
    activityScore: 85,
    hireDate: at(-210, 10),
    lastActiveAt: minutesAgo(130),
  },
  {
    id: 'emp-4',
    fullName: 'Фарход Сафаров',
    position: 'Основатель',
    department: 'Управление',
    email: 'farhod@webbrand.tj',
    phone: null,
    telegram: null,
    status: 'active',
    avatar: null,
    isSubAdmin: true,
    user: { id: 'u-founder', name: 'Фарход Сафаров', role: 'founder' },
    tasksCompleted: 240,
    tasksOverdue: 2,
    tasksReturned: 0,
    activityScore: 96,
    hireDate: at(-900, 10),
    lastActiveAt: minutesAgo(2),
  },
];

const clients = [
  {
    id: 'c-1',
    name: 'Mila Coffee',
    sphere: 'Кофейни',
    problem: 'Нужен системный контент и рост охватов перед открытием нового филиала.',
    contactPerson: 'Зарина Рахимова',
    contactPhone: '+992 93 100 20 30',
    contactInstagram: '@mila.coffee',
    contactEmail: 'hello@mila.tj',
    status: 'won',
    interest: 'hot',
    direction: 'smm',
    dealPotential: 12000,
    leadSource: 'Рекомендация',
    channel: 'Instagram',
    nextStep: 'Подготовить расширение тарифа на второй филиал.',
    nextContactAt: at(2, 11),
    lastContactAt: day(-3),
    lastActivityAt: minutesAgo(90),
    callRequested: false,
    owner: person('u-founder'),
    createdAt: at(-160, 10),
  },
  {
    id: 'c-2',
    name: 'Dushanbe Grand Hotel',
    sphere: 'Отели',
    problem: 'Слабая вовлечённость в Instagram, нужна ежедневная работа со сторис.',
    contactPerson: 'Азиз Шарипов',
    contactPhone: '+992 90 500 70 10',
    contactInstagram: '@grand.dushanbe',
    status: 'negotiating',
    interest: 'warm',
    direction: 'smm',
    dealPotential: 24000,
    leadSource: 'Холодный обзвон',
    channel: 'Telegram',
    nextStep: 'Отправить КП на SMM Premium и согласовать встречу.',
    nextContactAt: at(0, 15),
    lastContactAt: day(-1),
    lastActivityAt: minutesAgo(45),
    callRequested: true,
    callRequestedByName: 'Фарход Сафаров',
    owner: person('u-1'),
    createdAt: at(-40, 10),
  },
  {
    id: 'c-3',
    name: 'Zarif Market',
    sphere: 'Ритейл',
    problem: 'Нужен Telegram-бот для заказов и интеграция с CRM.',
    contactPerson: 'Сардор Юсупов',
    contactPhone: '+992 91 222 33 44',
    contactEmail: 's.yusupov@zarif.tj',
    status: 'proposal',
    interest: 'warm',
    direction: 'development',
    dealPotential: 45000,
    leadSource: 'Сайт',
    nextStep: 'Уточнить интеграцию с 1С.',
    nextContactAt: at(-1, 12),
    lastContactAt: day(-4),
    lastActivityAt: minutesAgo(1440),
    callRequested: false,
    owner: person('u-founder'),
    createdAt: at(-25, 10),
  },
  {
    id: 'c-4',
    name: 'Nur Beauty Studio',
    sphere: 'Бьюти',
    problem: 'Только начинают, интересуются пакетом сторис.',
    contactPerson: 'Нилуфар Азизова',
    contactInstagram: '@nur.beauty',
    status: 'new',
    interest: 'cold',
    direction: 'smm',
    dealPotential: 3500,
    leadSource: 'Instagram',
    nextStep: 'Позвонить и выяснить бюджет.',
    nextContactAt: at(1, 10),
    lastContactAt: null,
    lastActivityAt: minutesAgo(300),
    callRequested: false,
    owner: person('u-1'),
    createdAt: at(-2, 10),
  },
];

const notifications = [
  {
    id: 'n-1',
    type: 'task_overdue',
    title: 'Задача просрочена',
    message: '«Согласовать сентябрьский контент-план» просрочена на 1 день.',
    isRead: false,
    link: '/tasks/t-1',
    createdAt: minutesAgo(8),
  },
  {
    id: 'n-2',
    type: 'new_task',
    title: 'Новая задача от руководства',
    message: 'Съёмка 3 рилсов для Mila Coffee — дедлайн сегодня.',
    isRead: false,
    link: '/tasks/t-2',
    createdAt: minutesAgo(52),
  },
  {
    id: 'n-3',
    type: 'payment_reminder',
    title: 'Оплата отеля',
    message: 'Dushanbe Grand Hotel — оплата через 2 дня.',
    isRead: true,
    link: '/smm',
    createdAt: minutesAgo(180),
  },
  {
    id: 'n-4',
    type: 'stories_missing',
    title: 'Сторис не закрыты',
    message: 'Dushanbe Grand Hotel — 2 истории до нормы.',
    isRead: false,
    link: '/stories-check',
    createdAt: minutesAgo(400),
  },
  {
    id: 'n-5',
    type: 'task_completed',
    title: 'Задача выполнена',
    message: 'Мадина закрыла отчёт по охватам.',
    isRead: true,
    link: '/tasks/t-5',
    createdAt: minutesAgo(1500),
  },
];

const comments = [
  {
    id: 'cm-1',
    message: 'Клиент просил добавить два рилса про новый десерт.',
    authorId: 'u-1',
    author: people[1],
    createdAt: minutesAgo(120),
  },
  {
    id: 'cm-2',
    message: 'Принял, пересобрал сетку. Проверьте, пожалуйста, время публикаций.',
    authorId: 'u-founder',
    author: people[0],
    createdAt: minutesAgo(90),
  },
];

const results = [
  {
    id: 'r-1',
    type: 'text',
    content: 'Сетка на 8 рилсов и 12 постов готова, ссылка на Figma в файлах.',
    submittedBy: people[1],
    createdAt: minutesAgo(200),
  },
];

const checklist = [
  { id: 'cl-1', text: 'Проверить даты публикаций', isDone: true, doneAt: at(-1, 10) },
  { id: 'cl-2', text: 'Согласовать с клиентом', isDone: false },
];

const calendarEvents = [
  {
    id: 'ce-1',
    type: 'task',
    title: 'Согласовать февральский контент-план',
    date: at(-1, 18),
    time: '18:00',
    status: 'in_progress',
    priority: 'high',
    projectName: 'Mila Coffee',
    assigneeName: 'Мадина Каримова',
    taskId: 't-1',
  },
  {
    id: 'ce-2',
    type: 'task',
    title: 'Снять 3 рилса для Mila Coffee',
    date: at(0, 16, 30),
    time: '16:30',
    status: 'new',
    priority: 'critical',
    projectName: 'Mila Coffee',
    assigneeName: 'Далер Холов',
    taskId: 't-2',
  },
  {
    id: 'ce-3',
    type: 'task',
    title: 'Встреча с клиентом Dushanbe Grand Hotel',
    date: at(0, 14),
    time: '14:00',
    kind: 'meeting',
    status: 'new',
    projectName: 'Dushanbe Grand Hotel',
    assigneeName: 'Фарход Сафаров',
    taskId: 't-4',
  },
  {
    id: 'ce-4',
    type: 'shoot',
    title: 'Съёмка для Mila Coffee',
    date: at(2, 11),
    time: '11:00',
    location: 'Флагман на Рудаки',
    projectName: 'Mila Coffee',
  },
  {
    id: 'ce-5',
    type: 'client_payment',
    title: 'Оплата Dushanbe Grand Hotel',
    date: at(2, 10),
    time: '10:00',
    projectName: 'Dushanbe Grand Hotel',
    payState: 'pending',
  },
  {
    id: 'ce-6',
    type: 'client_meeting',
    title: 'Встреча с Zarif Market',
    date: at(1, 15),
    time: '15:00',
    location: 'Офис',
  },
];

const storyCheckProjects = [
  {
    id: 'p-1',
    name: 'Mila Coffee',
    target: 3,
    actual: 3,
    status: 'done',
    crew: [{ id: 'u-1', name: 'Мадина Каримова' }],
    posters: [{ id: 'u-1', name: 'Мадина Каримова', count: 3 }],
  },
  {
    id: 'p-2',
    name: 'Dushanbe Grand Hotel',
    target: 4,
    actual: 2,
    status: 'partial',
    crew: [{ id: 'u-1', name: 'Мадина Каримова' }],
    posters: [{ id: 'u-1', name: 'Мадина Каримова', count: 2 }],
  },
];

const routes = [
  ['POST', /^\/api\/auth\/login$/, () => ({ token: 'mock-access', refreshToken: 'mock-refresh', user })],
  ['POST', /^\/api\/auth\/refresh$/, () => ({ accessToken: 'mock-access-2', refreshToken: 'mock-refresh-2', user })],
  ['POST', /^\/api\/auth\/logout$/, () => ({ ok: true })],
  ['POST', /^\/api\/auth\/heartbeat$/, () => ({ ok: true })],
  ['POST', /^\/api\/auth\/forgot-password$/, () => ({ message: 'Если почта существует, письмо отправлено' })],
  ['PATCH', /^\/api\/auth\/change-password$/, () => ({ ok: true })],
  ['GET', /^\/api\/auth\/me$/, () => user],
  ['GET', /^\/api\/auth\/sessions$/, () => [{
    id: 's-1', userId: 'u-founder', loginAt: minutesAgo(95), logoutAt: null,
    lastSeenAt: minutesAgo(2), durationHours: 1.6, date: today,
  }]],
  ['POST', /^\/api\/users\/register-fcm$/, () => ({ ok: true })],
  ['POST', /^\/api\/users\/unregister-fcm$/, () => ({ ok: true })],
  ['PATCH', /^\/api\/users\/me\/avatar$/, () => ({ ok: true })],

  ['GET', /^\/api\/tasks\/my$/, () => tasks],
  ['GET', /^\/api\/tasks\/from-management$/, () => tasks.filter((t) => t.fromFounder)],
  ['GET', /^\/api\/tasks\/assigned-by-me$/, () => tasks.filter((t) => t.createdBy?.id === 'u-founder')],
  ['GET', /^\/api\/tasks\/stats$/, () => [
    { status: 'new', count: 3 }, { status: 'in_progress', count: 2 }, { status: 'done', count: 1 },
  ]],
  ['GET', /^\/api\/tasks$/, () => tasks.filter((t) => !t.project || !t.project.id || true)],
  ['GET', /^\/api\/tasks\/([^/]+)\/comments$/, () => comments],
  ['GET', /^\/api\/tasks\/([^/]+)\/results$/, () => results],
  ['GET', /^\/api\/tasks\/([^/]+)\/checklist$/, () => checklist],
  ['GET', /^\/api\/tasks\/([^/]+)$/, (m) => tasks.find((t) => t.id === m[1]) || tasks[0]],
  ['PATCH', /^\/api\/tasks\/[^/]+$/, () => ({ ok: true })],
  ['POST', /^\/api\/tasks$/, () => ({ id: 't-new', ...tasks[0] })],
  ['POST', /^\/api\/tasks\/[^/]+\/(my-part-done|approve|return)$/, () => ({ ok: true })],
  ['POST', /^\/api\/tasks\/[^/]+\/comments$/, () => ({ id: 'cm-new' })],
  ['POST', /^\/api\/tasks\/[^/]+\/results$/, () => ({ id: 'r-new' })],
  ['POST', /^\/api\/tasks\/[^/]+\/checklist$/, () => ({ id: 'cl-new' })],
  ['PATCH', /^\/api\/tasks\/[^/]+\/checklist\/[^/]+\/toggle$/, () => ({ ok: true })],
  ['DELETE', /^\/api\/tasks\/[^/]+\/results\/[^/]+$/, () => ({ ok: true })],

  ['GET', /^\/api\/projects\/stats$/, () => [
    { status: 'in_progress', count: 2 }, { status: 'planning', count: 1 },
  ]],
  ['GET', /^\/api\/projects$/, () => projects],
  ['GET', /^\/api\/projects\/([^/]+)$/, (m) => projects.find((p) => p.id === m[1]) || projects[0]],

  ['GET', /^\/api\/calendar\/events$/, () => calendarEvents],

  ['GET', /^\/api\/content-plan\/smm-calendar$/, () => ({
    from: day(-40), to: day(40), events: smmEvents, projects: smmProjects, backlog, colorIds: [],
  })],
  ['GET', /^\/api\/content-plan\/plan-fact\/([^/]+)$/, () => [
    { contentType: 'reel', planned: 8, published: 5, cancelled: 0, remaining: 3 },
    { contentType: 'post', planned: 12, published: 9, cancelled: 1, remaining: 2 },
    { contentType: 'story', planned: 90, published: 72, cancelled: 0, remaining: 18 },
  ]],
  ['POST', /^\/api\/content-plan$/, () => ({ id: 'ci-new' })],
  ['PATCH', /^\/api\/content-plan\/smart-item\/[^/]+$/, () => ({ ok: true })],
  ['PATCH', /^\/api\/content-plan\/[^/]+$/, () => ({ ok: true })],
  ['PATCH', /^\/api\/content-plan\/my-work\/[^/]+$/, () => ({ ok: true })],

  ['GET', /^\/api\/stories\/my$/, () => [
    {
      id: 'sl-1', projectId: 'p-1', project: { id: 'p-1', name: 'Mila Coffee' },
      date: day(0), storiesCount: 3, employee: people[1],
    },
    {
      id: 'sl-2', projectId: 'p-2', project: { id: 'p-2', name: 'Dushanbe Grand Hotel' },
      date: day(0), storiesCount: 2, employee: people[1],
    },
  ]],
  ['GET', /^\/api\/stories\/check\/day$/, () => ({
    date: day(0), today: day(0), future: false,
    projects: storyCheckProjects,
    people: [{ id: 'u-1', name: 'Мадина Каримова', projectIds: ['p-1', 'p-2'] }],
    totals: { projects: 2, done: 1, partial: 1, none: 0 },
  })],
  ['POST', /^\/api\/stories$/, () => ({ ok: true })],

  ['GET', /^\/api\/employees$/, () => employees],
  ['GET', /^\/api\/employees\/([^/]+)$/, (m) => employees.find((e) => e.id === m[1]) || employees[0]],

  ['GET', /^\/api\/clients$/, () => clients],
  ['GET', /^\/api\/clients\/([^/]+)$/, (m) => clients.find((c) => c.id === m[1]) || clients[0]],
  ['POST', /^\/api\/clients$/, () => ({ id: 'c-new' })],
  ['PATCH', /^\/api\/clients\/[^/]+$/, () => ({ ok: true })],
  ['POST', /^\/api\/clients\/call-request$/, () => ({ ok: true })],

  ['GET', /^\/api\/notifications\/unread-count$/, () => ({ count: notifications.filter((n) => !n.isRead).length })],
  ['GET', /^\/api\/notifications$/, () => notifications],
  ['PATCH', /^\/api\/notifications\/read-all$/, () => ({ ok: true })],
  ['PATCH', /^\/api\/notifications\/[^/]+\/read$/, () => ({ ok: true })],
  ['DELETE', /^\/api\/notifications\/[^/]+$/, () => ({ ok: true })],

  ['GET', /^\/api\/files\/task\/[^/]+$/, () => []],
  ['POST', /^\/api\/files\/upload$/, () => ({ id: 'f-1', originalName: 'file.png', path: 'uploads/file.png' })],

  ['GET', /^\/api\/analytics\/dashboard$/, () => ({
    overview: {
      totalProjects: 3, activeProjects: 2, totalTasks: 36, doneTasks: 19,
      completionRate: 53, totalEmployees: 4, totalUsers: 4, overdueTasks: 2,
      hoursThisMonth: 128.5,
    },
    projByStatus: [{ status: 'in_progress', count: 2 }, { status: 'planning', count: 1 }],
    taskByStatus: [
      { status: 'new', count: 3 }, { status: 'in_progress', count: 3 }, { status: 'done', count: 1 },
    ],
    taskByPriority: [{ priority: 'critical', count: 2 }, { priority: 'high', count: 5 }, { priority: 'medium', count: 12 }],
    empActivity: [
      { id: 'u-1', name: 'Мадина Каримова', completedTasks: 8, loggedHours: 34.5 },
      { id: 'u-2', name: 'Рустам Назаров', completedTasks: 6, loggedHours: 28.0 },
    ],
    hoursPerDay: [], projPerf: [], empEff: [],
  })],

  ['GET', /^\/api\/finance\/overview/, () => ({
    income: 148500,
    expense: 86200,
    profit: 62300,
    receivables: 32000,
    balances: [
      { id: 'acc-1', name: 'Алиф Банк', balance: 74200, currency: 'TJS' },
      { id: 'acc-2', name: 'Касса офис', balance: 18500, currency: 'TJS' },
      { id: 'acc-3', name: 'Сейф', balance: 55800, currency: 'TJS' },
    ],
    recentTransactions: [
      { id: 'tx-1', type: 'income', amount: 24000, description: 'Оплата за SMM пакет Premium', accountName: 'Алиф Банк', date: at(-1, 14) },
      { id: 'tx-2', type: 'expense', amount: 8500, description: 'Аренда офиса за текущий месяц', accountName: 'Касса офис', date: at(-3, 11) },
      { id: 'tx-3', type: 'income', amount: 12500, description: 'Разработка лендинга (этап 1)', accountName: 'Алиф Банк', date: at(-5, 16) },
    ],
  })],
  ['POST', /^\/api\/finance\/operations$/, () => ({ ok: true, id: 'tx-new' })],

  ['GET', /^\/api\/dev-tracker/, () => [
    { id: 'dt-1', taskNumber: 101, title: 'Аутентификация через биометрию', status: 'in_progress', priority: 'high', type: 'feature', projectName: 'Sabt Mobile', assigneeName: 'Далер Холов' },
    { id: 'dt-2', taskNumber: 102, title: 'Оптимизация оффлайн-кэша Hive', status: 'review', priority: 'critical', type: 'refactor', projectName: 'Sabt Mobile', assigneeName: 'Фарход Сафаров' },
    { id: 'dt-3', taskNumber: 103, title: 'Фикс отображения графиков на iOS', status: 'todo', priority: 'medium', type: 'bug', projectName: 'Sabt Mobile' },
    { id: 'dt-4', taskNumber: 104, title: 'Синхронизация фоновых пушей FCM', status: 'done', priority: 'high', type: 'feature', projectName: 'Sabt Mobile', assigneeName: 'Фарход Сафаров' },
  ]],
  ['PATCH', /^\/api\/dev-tracker\/[^/]+(\/move)?$/, () => ({ ok: true })],

  ['GET', /^\/api\/files\/project\/[^/]+$/, () => [
    { id: 'f-1', originalName: 'Brandbook_WeBrand_2026.pdf', mimeType: 'application/pdf', size: 14857600, createdAt: at(-10, 11), userName: 'Фарход Сафаров', url: 'uploads/brandbook.pdf' },
    { id: 'f-2', originalName: 'KeyVisual_Sabt_Final.png', mimeType: 'image/png', size: 3420000, createdAt: at(-4, 15), userName: 'Рустам Назаров', url: 'uploads/kv.png' },
    { id: 'f-3', originalName: 'Contracts_Archive.zip', mimeType: 'application/zip', size: 8540000, createdAt: at(-2, 9), userName: 'Мадина Каримова', url: 'uploads/contracts.zip' },
  ]],
  ['DELETE', /^\/api\/files\/[^/]+$/, () => ({ ok: true })],

  ['GET', /^\/api\/smm-tariffs/, () => [
    { id: 'st-1', name: 'Start SMM', description: 'Базовое ведение аккаунта', monthlyPrice: 4500, storiesPerMonth: 60, reelsPerMonth: 8, postsPerMonth: 12, designsPerMonth: 4, shootingDaysPerMonth: 1, isActive: true },
    { id: 'st-2', name: 'Business Pro', description: 'Комплексный маркетинг с видеосъемкой', monthlyPrice: 8900, storiesPerMonth: 120, reelsPerMonth: 16, postsPerMonth: 20, designsPerMonth: 8, shootingDaysPerMonth: 2, isActive: true },
    { id: 'st-3', name: 'Enterprise Elite', description: 'Полное медиасопровождение бренда', monthlyPrice: 16000, storiesPerMonth: 200, reelsPerMonth: 30, postsPerMonth: 30, designsPerMonth: 16, shootingDaysPerMonth: 4, isActive: true },
  ]],
  ['PATCH', /^\/api\/smm-tariffs\/[^/]+\/toggle-active$/, () => ({ ok: true })],
  ['PATCH', /^\/api\/projects\/[^/]+\/archive$/, () => ({ ok: true })],

  // ── Notes ─────────────────────────────────────────────────────────────
  ['GET', /^\/api\/my-notes$/, () => [
    { id: 'note-1', text: 'Согласовать концепцию рилсов для Mila Coffee', date: today, done: false, createdAt: at(-1, 10) },
    { id: 'note-2', text: 'Проверить рендеры сторис к запуску акции', date: today, done: true, createdAt: at(-2, 12) },
    { id: 'note-3', text: 'Подготовить KPI-отчет за прошлый месяц', date: day(2), done: false, createdAt: at(-3, 16) },
  ]],
  ['POST', /^\/api\/my-notes$/, () => ({ id: 'note-new', text: 'Новая заметка', date: today, done: false })],
  ['PATCH', /^\/api\/my-notes\/[^/]+$/, () => ({ ok: true })],
  ['DELETE', /^\/api\/my-notes\/[^/]+$/, () => ({ ok: true })],

  // ── AI Assistant ──────────────────────────────────────────────────────
  ['GET', /^\/api\/ai\/models$/, () => ['gemini-2.0-flash', 'gemini-1.5-pro']],
  ['POST', /^\/api\/ai\/chat$/, () => ({
    reply: 'Привет! По проекту Mila Coffee все 12 задач выполнены в срок. По проекту Payk мобильная версия завершена и проходит тестирование. Рекомендую обратить внимание на дедлайн по проекту Rangorang.'
  })],

  // ── Risks ─────────────────────────────────────────────────────────────
  ['GET', /^\/api\/risk-analytics\/risks\/projects$/, () => [
    {
      projectId: 'p-1', projectName: 'Mila Coffee', managerName: 'Фарход Сафаров', level: 'green', score: 10,
      factors: [{ key: 'deadline', label: 'Дедлайны в норме', triggered: false }]
    },
    {
      projectId: 'p-2', projectName: 'Rangorang Fashion', managerName: 'Рустам Назаров', level: 'yellow', score: 45,
      factors: [{ key: 'late_content', label: 'Отставание от контент-плана на 2 дня', triggered: true }]
    },
    {
      projectId: 'p-3', projectName: 'Payk Mobile App', managerName: 'Фарход Сафаров', level: 'red', score: 80,
      factors: [
        { key: 'delay_review', label: 'Задержка ревью в App Store более 5 дней', triggered: true },
        { key: 'overdue_tasks', label: '3 просроченные критические задачи', triggered: true }
      ]
    },
  ]],
  ['GET', /^\/api\/risk-analytics\/workload\/employees$/, () => [
    { userId: 'u-1', userName: 'Мадина Каримова', role: 'SMM специалист', projectCount: 4, tasksInProgress: 6, tasksInQueue: 2, overload: 'green' },
    { userId: 'u-2', userName: 'Рустам Назаров', role: 'Дизайнер', projectCount: 5, tasksInProgress: 9, tasksInQueue: 5, overload: 'red' },
    { userId: 'u-3', userName: 'Далер Холов', role: 'Видеограф', projectCount: 3, tasksInProgress: 4, tasksInQueue: 1, overload: 'yellow' },
  ]],

  // ── Security Log ──────────────────────────────────────────────────────
  ['GET', /^\/api\/activity-log/, () => [
    { id: 'act-1', action: 'LOGIN', userName: 'Фарход Сафаров', details: 'Успешная авторизация по паролю', ipAddress: '212.11.34.12', createdAt: minutesAgo(12) },
    { id: 'act-2', action: 'TASK_STATUS', userName: 'Рустам Назаров', details: 'Задача переведена в статус "Готово"', ipAddress: '212.11.34.15', createdAt: minutesAgo(45) },
    { id: 'act-3', action: 'FILE_UPLOAD', userName: 'Мадина Каримова', details: 'Загружен файл Brandbook_2026.pdf', ipAddress: '212.11.34.18', createdAt: minutesAgo(120) },
    { id: 'act-4', action: 'PROJECT_UPDATE', userName: 'Фарход Сафаров', details: 'Обновлен тариф проекта Mila Coffee', ipAddress: '212.11.34.12', createdAt: minutesAgo(240) },
  ]],

  // ── Transport Requests ────────────────────────────────────────────────
  ['GET', /^\/api\/transport-requests\/my$/, () => ({
    totalPaidThisMonth: 450,
    totalPending: 85,
    requests: [
      { id: 'tr-1', employeeName: 'Фарход Сафаров', projectName: 'Mila Coffee', amount: 45, date: today, status: 'pending', note: 'Такси на локацию съемок (Рудаки 55)' },
      { id: 'tr-2', employeeName: 'Фарход Сафаров', projectName: 'Payk Mobile App', amount: 40, date: day(-1), status: 'pending', note: 'Поездка на встречу с клиентом' },
      { id: 'tr-3', employeeName: 'Фарход Сафаров', projectName: 'Mila Coffee', amount: 120, date: day(-5), status: 'paid', note: 'Транспорт команды с оборудованием' },
    ]
  })],
  ['POST', /^\/api\/transport-requests$/, () => ({ ok: true })],
  ['DELETE', /^\/api\/transport-requests\/[^/]+$/, () => ({ ok: true })],

  // ── Employee Access ───────────────────────────────────────────────────
  ['GET', /^\/api\/users\/access$/, () => [
    { id: 'u-founder', name: 'Фарход Сафаров', email: 'farhod@webbrand.tj', role: 'founder', position: 'Основатель', extraPermissions: ['finance.manage', 'risks.view', 'ai.chat'], isActive: true },
    { id: 'u-1', name: 'Мадина Каримова', email: 'madina@webbrand.tj', role: 'smm_specialist', position: 'SMM специалист', extraPermissions: ['stories.manage', 'notes.use'], isActive: true },
    { id: 'u-2', name: 'Рустам Назаров', email: 'rustam@webbrand.tj', role: 'designer', position: 'Графический дизайнер', extraPermissions: ['files.upload'], isActive: true },
  ]],
  ['GET', /^\/api\/users\/access-catalog$/, () => [
    { key: 'finance.view', label: 'Просмотр финансов', category: 'Финансы', danger: false },
    { key: 'finance.manage', label: 'Управление кассой и счетами', category: 'Финансы', danger: true },
    { key: 'risks.view', label: 'Просмотр рисков и нагрузки', category: 'Аналитика', danger: false },
    { key: 'smm.manage', label: 'Управление SMM-проектами', category: 'SMM', danger: false },
    { key: 'stories.manage', label: 'Управление сторис', category: 'SMM', danger: false },
    { key: 'notes.use', label: 'Личные заметки', category: 'Инструменты', danger: false },
    { key: 'ai.chat', label: 'Доступ к ИИ-помощнику', category: 'Инструменты', danger: false },
  ]],
  ['PATCH', /^\/api\/users\/[^/]+\/permissions$/, () => ({ ok: true })],

  // ── SMM Control ───────────────────────────────────────────────────────
  ['GET', /^\/api\/smm-control/, () => ({
    ym: today.slice(0, 7),
    projects: [
      { id: 'p-1', name: 'Mila Coffee', mood: 'good', reels: { done: 12, norm: 12 }, posts: { done: 15, norm: 15 } },
      { id: 'p-2', name: 'Rangorang Fashion', mood: 'meh', reels: { done: 6, norm: 10 }, posts: { done: 8, norm: 12 } },
      { id: 'p-3', name: 'Payk Mobile', mood: 'good', reels: { done: 4, norm: 4 }, posts: { done: 6, norm: 6 } },
    ]
  })],
];

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.wasm': 'application/wasm',
  '.bin': 'application/octet-stream',
};

function sendJson(res, status, body) {
  const data = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Allow-Methods': 'GET,POST,PATCH,PUT,DELETE,OPTIONS',
    'Cache-Control': 'no-store',
  });
  res.end(data);
}

function serveStatic(req, res, pathname) {
  let rel = decodeURIComponent(pathname === '/' ? '/index.html' : pathname);
  let file = path.join(WEB_ROOT, rel);
  if (!file.startsWith(WEB_ROOT)) {
    res.writeHead(403);
    res.end();
    return;
  }
  if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    file = path.join(WEB_ROOT, 'index.html');
  }
  fs.readFile(file, (error, data) => {
    if (error) {
      res.writeHead(404);
      res.end('Build the web app first: flutter build web');
      return;
    }
    res.writeHead(200, {
      'Content-Type': MIME[path.extname(file)] || 'application/octet-stream',
      'Cache-Control': 'no-store',
    });
    res.end(data);
  });
}

const server = http.createServer((req, res) => {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': '*',
      'Access-Control-Allow-Methods': 'GET,POST,PATCH,PUT,DELETE,OPTIONS',
    });
    res.end();
    return;
  }

  const url = new URL(req.url, `http://localhost:${PORT}`);
  if (!url.pathname.startsWith('/api/')) {
    serveStatic(req, res, url.pathname);
    return;
  }

  for (const [method, pattern, handler] of routes) {
    if (req.method !== method) continue;
    const match = url.pathname.match(pattern);
    if (!match) continue;
    let body = '';
    req.on('data', (chunk) => (body += chunk));
    req.on('end', () => {
      try {
        if (body) JSON.parse(body);
      } catch (_) {}
      console.log(method, url.pathname);
      sendJson(res, 200, handler(match));
    });
    return;
  }

  console.log('MOCK 404', req.method, url.pathname);
  sendJson(res, 404, { message: `Mock endpoint not implemented: ${req.method} ${url.pathname}` });
});

server.listen(PORT, () => {
  console.log(`Sabt mock API + web on http://localhost:${PORT}`);
  console.log(`Static root: ${WEB_ROOT}`);
});
