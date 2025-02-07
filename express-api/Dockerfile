
FROM node:22

RUN npm -g install npm@latest

WORKDIR /home/app

COPY package*.json ./

RUN npm install

COPY . .

RUN npm run build

EXPOSE 3000
CMD ["npm","run", "start"]
