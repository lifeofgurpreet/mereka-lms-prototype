import { onRequest } from "firebase-functions/v2/https";
import moment from "moment";
import express from "express";
import axios from "axios";
import FormData from "form-data";
import bodyParser from "body-parser";
import GridMail from "./sgrid.js";
import { setGlobalOptions } from "firebase-functions/v2";
import "isomorphic-fetch";
import { Client } from "@microsoft/microsoft-graph-client";
import { ClientSecretCredential } from "@azure/identity";
import { TokenCredentialAuthenticationProvider } from "@microsoft/microsoft-graph-client/authProviders/azureTokenCredentials/index.js";
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { onSchedule } from "firebase-functions/v2/scheduler";
// Initialize Firebase Admin SDK
initializeApp();
const db = getFirestore();

const credential = new ClientSecretCredential(
  process.env.AZURE_TENANT_ID,
  process.env.AZURE_CLIENT_ID,
  process.env.AZURE_CLIENT_SECRET,
);

const authProvider = new TokenCredentialAuthenticationProvider(credential, {
  scopes: ['https://graph.microsoft.com/.default'],
});
const options = {
  authProvider,
};

const client = Client.initWithMiddleware(options);
setGlobalOptions({ maxInstances: 10 });

const app = express();
app.use(bodyParser.json());

const MCT_ENDPT = process.env.MCT_ENDPT;
const MCT_CLIENT_ID = process.env.MCT_CLIENT_ID;
const MCT_CLIENT_SECRET = process.env.MCT_CLIENT_SECRET;
const MCT_API_URI = process.env.MCT_API_URI;
const MCT_TENANT_ID = process.env.MCT_TENANT_ID;
const SGRID_API_KEY = process.env.SGRID_API_KEY;
const SGRID_FROM_EMAIL = process.env.SGRID_FROM_EMAIL;
const substringsToCheck = ['1kTBgf9zSQl2J4KhZWBh8Tw5437v', '1DQqCAAJfSzCDlK_rPCReEg5437v', '1UkBP9VPoRgymtkMFCPmHtg5437v', '1MWgao74AS-mixdrxJm46XA5437v', '1eASlzPOxQCK5yddvT2P0jg5437v'];
const sendGridIdsForVariousLanguage = {
  '1MWgao74AS-mixdrxJm46XA5437v': 'd-f3d06a9f4eb54205852a89372767e84c', //vetname
  '1UkBP9VPoRgymtkMFCPmHtg5437v': 'd-acc754366ab54e6194a4d0b5cd62c2ad', //phillpines
  '1kTBgf9zSQl2J4KhZWBh8Tw5437v': 'd-54113e54930f49a59d0c898cb2cf7cd7', //ENGLISH
  '1DQqCAAJfSzCDlK_rPCReEg5437v': 'd-b47fdecdfaff497eba49b2089da06917',//INDONESIAN
  "1eASlzPOxQCK5yddvT2P0jg5437v": "d-35b735b3c1e74f5ebe2e3ea45d7bcd86" //chinese
}
const sendGridUidsofReminderEmailforVariousLanguage = {
  '1MWgao74AS-mixdrxJm46XA5437v': 'd-5bb3cde391744cab984ed64ed3a024e2', //vetname
  '1UkBP9VPoRgymtkMFCPmHtg5437v': 'd-7c0c729177e249748ad13e585c468d87', //phillpines
  '1kTBgf9zSQl2J4KhZWBh8Tw5437v': 'd-94ab74b048d7469ca7e71d7edce66e9a', //ENGLISH
  '1DQqCAAJfSzCDlK_rPCReEg5437v': 'd-0ccb77f1fe4f4924b293328a6ea77158',//INDONESIAN
  "1eASlzPOxQCK5yddvT2P0jg5437v": "d-90269d4b9ae140758307806e331fe5e9" //chinese
}
app.post("/api/createUser", async (req, res) => {
  await new Promise((resolve) => setTimeout(resolve, 10000));
  console.log("Request Body", req.body)
  GridMail.setApiKey(SGRID_API_KEY);

  // Get SendGrid API key
  const akey = await getApiKey();
  // Get organizations and create a map for easy lookup
  let organization_arr = await get_organizations(akey);
  console.log("Fetched Organization")
  let orgmap = {};
  for (const org of organization_arr) {
    orgmap[org.name] = org.id;
  }

  // Get contactId information from the webhook request
  const contactId = req.body[0].objectId;
  if (!contactId) {
    console.error("Contact ID not found");
    return res.status(500).json({ message: "Contact ID not found" });
  }
  let userEmail;
  let formguid;
  let pageUrl;
  let idOfForm;
  let cityData1
  let subs = [];
  let createdDate = new Date().toISOString();
  let university = '';
  let referralPartner = '';
  try {
    const { email, formGuid, pageUrl1, cityData, subsData, createDate, university1, referralPartner1 } = await getContactInfo(contactId);
    console.log("Email found:", email);
    userEmail = email;
    formguid = formGuid;
    pageUrl = pageUrl1;
    createdDate = createDate;
    idOfForm = pageUrl.split('/').pop();
    cityData1 = cityData;
    subs = subsData;
    university = university1;
    referralPartner = referralPartner1;
  } catch (error) {
    sendErrorEmail("Error in fetching contact info");
    return res.status(500).json({ message: "Internal Server Error" });
  }

  function containsAnySubstring(url, substrings) {
    return substrings.some(substring => url.includes(substring));
  }


  if (containsAnySubstring(pageUrl, substringsToCheck)) {
    console.log('Request is coming from one of the form');
    // Your combined logic here
  } else {
    console.log('Request is not coming from one of the form');
    return res.status(500).json({ message: "Req from different URL" });
    // Your alternative logic here
  }

  if (subs.length == 0) {
    sendErrorEmail(`There is no form submission found: ${userEmail}`,);
    return res.status(500).json({ message: "No form submission found" });
  }

  // Iterate over form submissions
  for (const sub of subs) {

    const emailes = sub.values.filter((e) => e.name === "email");
    let email = emailes[0].value.toString();
    const userDetailsInmct = await lookup_user(akey, email);

    if (email === userEmail) {
      const emails = sub.values.filter((e) => e.name === "email");
      const countries = sub.values.filter(
        (e) => e.name === "country_territory"
      );
      const nicknames = sub.values.filter((e) => e.name === "nickname");
      const firstname = sub.values
        .find((e) => e.name === "firstname")?.value?.toString() ?? '';
      const lastname = sub.values
        .find((e) => e.name === "lastname")?.value?.toString() ?? '';
      const city = cityData1 ?? '';
      const gender = sub.values
        .find((e) => e.name === "gender_new")?.value?.toString() ?? '';
      const birthDate = sub.values
        .find((e) => e.name === "birth_date")?.value?.toString() ?? '';
      const lnob = sub.values
        .find((e) => e.name === "lnob_type")?.value?.toString() ?? '';
      const mctLearning = sub.values
        .find((e) => e.name === "mct_learning_categories_interest")?.value?.toString() ?? '';
      const linkedInValue = sub.values.filter((e) => e.name === "linkedin")[0];

      let linkedIn;
      if (linkedInValue) {
        linkedIn = linkedInValue.value.toString();
      } else {
        linkedIn = "";
      }

      const lnobTypesArray = sub.values
        .filter((item) => item.name === "lnob_type")
        .map((item) => item.value);
      const mctLearningArray = sub.values
        .filter((item) => item.name === "mct_learning_categories_interest")
        .map((item) => item.value);
      const is_project_manager =
        sub.values.filter(
          (e) =>
            e.name === "mct_learning_categories_interest" &&
            e.value === "Project Manager"
        ).length > 0;
      const is_data_analyst =
        sub.values.filter(
          (e) =>
            e.name === "mct_learning_categories_interest" &&
            e.value === "Data Analyst"
        ).length > 0;
      const is_developer =
        sub.values.filter(
          (e) =>
            e.name === "mct_learning_categories_interest" &&
            e.value === "Developer"
        ).length > 0;
      const is_admin_prof =
        sub.values.filter(
          (e) =>
            e.name === "mct_learning_categories_interest" &&
            e.value === "Administrative Professional"
        ).length > 0;
      const is_marketer =
        sub.values.filter(
          (e) =>
            e.name === "mct_learning_categories_interest" &&
            e.value === "Digital Marketer"
        ).length > 0;

      const mct_channels = sub.values
        .filter((item) => item.name === "mct_channels")
        .map((item) => item.value);
      const consent = sub.values
        .filter((e) => e.name === "consent")[0]
        .value.toString();

      if (emails.length > 0 && countries.length > 0) {
        let email = emails[0].value.toString();
        let country = countries[0].value.toString();
        let orgid = orgmap[country] || 1;
        let nickname =
          nicknames.length > 0 ? nicknames[0].value.toString() : undefined;
        // Create the user in MCT
        if (userDetailsInmct.length <= 0) {
          console.log("Creating user in mct");
          try {
            await create_user(akey, { email: email }, orgid);
            console.log("Created user in mct");
          } catch (e) {
            console.log("ISSUE when trying to create user", e);
            return res.status(500).json({ message: "Failed to create user" });
          }
        }

        // GET the user details in MCT
        try {
          const details = await lookup_user(akey, email);
          if (details.length < 1) {
            console.log("WARNING! Unable to get user id");
            // continue;
          }

          // Update the user details in MCT
          const uid = details[0].Id;
          console.log("Got ID of user:", uid);
          await update_name(
            akey,
            orgid,
            uid,
            email,
            firstname,
            lastname,
            nickname,
            country,
            gender,
            birthDate,
            lnob,
            city,
            mctLearning,
            linkedIn,
            mctLearningArray,
            lnobTypesArray,
            mct_channels,
            consent,
            createdDate,
            university,
            referralPartner
          );
          console.log("User is updated in MCT");

          if (userDetailsInmct.length <= 0) {
            let password = generateStrongPassword(10)
            try {
              //creating user in b2c
              await client.api('/users')
                .post({
                  displayName: `${firstname} ${lastname}`,
                  // userPrincipalName: email.replace(/@[^@]+$/, "@skillourfuture.onmicrosoft.com"),
                  mail: email,
                  identities: [
                    {
                      signInType: 'emailAddress',
                      issuer: 'skillourfuture.onmicrosoft.com',
                      issuerAssignedId: email
                    },
                  ],
                  passwordProfile: {
                    password: password,
                    forceChangePasswordNextSignIn: false
                  },
                  passwordPolicies: 'DisablePasswordExpiration'
                })
              try {
                await db.collection('emails')
                  .add({
                    toEmail: email || '',
                    data: {
                      nickname: `${firstname} ${lastname}`,
                      password: password || '',
                    },
                    scheduleDate: moment().add(7, 'days').toDate(),
                    sent: false,
                    templateId: sendGridUidsofReminderEmailforVariousLanguage[idOfForm] || '',
                    createdDate: new Date()
                  });
              } catch (error) {
                console.log("Error in adding email to firestore", error);
              }

              console.log("User is created in A2C");
            } catch (error) {
              sendErrorEmail(`Error in creating user in b2c ${email}`,);
              console.log("Error in creating user in b2c", error);
            }

            console.log("Sending gridmail...");
            try {
              const grid_mailer = new GridMail()
                .setTemplate(sendGridIdsForVariousLanguage[idOfForm])
                .setFrom(SGRID_FROM_EMAIL);
              // Send grid mail
              let mailer = await grid_mailer
                .setTemplateData({
                  username: email,
                  password: password,
                  nickname: nickname,
                })
                .setTo(email)
                .send();
              console.log(JSON.parse(JSON.stringify(mailer)));
            } catch (e) {
              sendErrorEmail(`Error in sending email: ${email}`,);

              console.log("WARNING: Failed to send email. Error details:", e);

              // Log the specific error details if available
              if (e.response && e.response.body && e.response.body.errors) {
                console.log("Error details:", e.response.body.errors);
              }

              return res.status(500).json({ message: "Failed to send email" });
            }


          }
        } catch (e) {

          console.log("WARNING! Unable to get user id or update name", e);
          return res
            .status(500)
            .json({ message: "Failed to get user details or update name" });
          // continue;
        }
      } else {
        console.log(
          "WARNING: User is not created because email and/or country is not set!"
        );
      }
      return res.status(200).json({ message: "success" });

      // }
    } else {
      return res.status(500).json({ message: "Internal Server Error" });
    }
  }
});
//It will generate the random password
function generateStrongPassword(length) {
  const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+~`|}{[]:;?><,./-=";
  let password = "";
  for (let i = 0, n = charset.length; i < length; ++i) {
    password += charset.charAt(Math.floor(Math.random() * n));
  }
  console.log(password);
  return password;
}

async function get_organizations(akey) {
  try {
    let options = {
      url: `https://${MCT_ENDPT}/api/v1/organization`,
      method: "GET",
      headers: {
        Authorization: `Bearer ${akey}`,
        ClientType: "service",
      },
    };

    const response = await axios(options);
    return response.data;
  } catch (error) {
    console.log(`Error: ${JSON.stringify(error.toJSON(), null, 4)}`);
    throw error;
  }
}

async function create_user(akey, params, orgid) {
  try {
    const email = params["email"];
    if (!email) {
      throw new Error("email not defined");
    }

    const formData = new FormData();
    formData.append("Contacts", JSON.stringify([email]));
    formData.append(
      "CsvDoc",
      JSON.stringify({ users: [{ firstName: "testfirst" }] })
    );

    let queryStr = "";
    if (orgid) {
      queryStr = `?orgId=${orgid}`;
    }

    const options = {
      url: `https://${MCT_ENDPT}/api/v1/users${queryStr}`,
      method: "POST",
      headers: {
        ...formData.getHeaders(),
        Authorization: `Bearer ${akey}`,
        ClientType: "service",
      },
      data: formData,
    };

    const response = await axios(options);

    return response.data;
  } catch (error) {
    sendErrorEmail(`Error in creating user: ${JSON.stringify(error.toJSON(), null, 4)}`);
    throw error;
  }
}

function convertTimestampToDOB(timestamp) {
  const dob = new Date(timestamp);
  const day = dob.getDate().toString().padStart(2, "0");
  const month = (dob.getMonth() + 1).toString().padStart(2, "0");
  const year = dob.getFullYear();
  return `${day}/${month}/${year}`;
}

async function update_name(
  akey,
  orgid,
  userid,
  email,
  firstname,
  lastname,
  nickname,
  country,
  gender,
  birthDate,
  lnob,
  city,
  mctLearning,
  linkedIn,
  mctLearningArray,
  lnobTypesArray,
  mct_channels,
  consent,
  createdDate,
  university = '',
  referralPartner = ''
) {
  try {
    const structure = [
      {
        Value: firstname,
        DefaultValue: null,
        ValidationLogic: null,
        MappingId: -1,
        Name: [{ LanguageCode: "en-US", Value: "First Name", IsDefault: true }],
        Type: "TextfieldUnit",
        DisplayOrder: 1,
        Editable: true,
        Mandatory: true,
        Hidden: false,
        TopLevelMappingId: 0,
        Masked: false,
      },
      {
        Value: lastname,
        DefaultValue: null,
        ValidationLogic: null,
        MappingId: -2,
        Name: [{ LanguageCode: "en-US", Value: "Last Name", IsDefault: true }],
        Type: "TextfieldUnit",
        DisplayOrder: 2,
        Editable: true,
        Mandatory: true,
        Hidden: false,
        TopLevelMappingId: 0,
        Masked: false,
      },
      {
        Value: email,
        DefaultValue: null,
        ValidationLogic: null,
        MappingId: -3,
        Name: [{ LanguageCode: "en-US", Value: "Contact", IsDefault: true }],
        Type: "TextfieldUnit",
        DisplayOrder: 3,
        Editable: false,
        Mandatory: true,
        Hidden: false,
        TopLevelMappingId: 0,
        Masked: false,
      },
      {
        Value: nickname,
        DefaultValue: null,
        ValidationLogic: [
          {
            Regex: null,
            ErrorMessage: [
              {
                LanguageCode: "en-US",
                Description: "How should we address you?",
                Value: "",
              },
            ],
            AssociationValue: null,
          },
        ],
        MappingId: 7,
        Name: [
          {
            LanguageCode: "en-US",
            Value: "Nickname",
            IsDefault: true,
          },
          {
            LanguageCode: "id-ID",
            Value: "Nama Panggilan",
            IsDefault: false,
          },
        ],
        Type: "TextfieldUnit",
        DisplayOrder: 6,
        Editable: true,
        Mandatory: false,
        Hidden: true,
        TopLevelMappingId: 0,
        Masked: false,
      },
      {
        Value: gender,
        "DefaultValue": null,
        "PossibleValuesFileUri": null,
        "NumberPossibleValues": 5,
        "PossibleValues": [
          {
            "associationValue": null,
            "value": "Man"
          },
          {
            "associationValue": null,
            "value": "Woman"
          },
          {
            "associationValue": null,
            "value": "Prefer not to say"
          },
          {
            "associationValue": null,
            "value": "Other"
          },
          {
            "associationValue": null,
            "value": "Non-binary"
          }
        ],
        "MappingId": 2,
        "Name": [
          {
            "LanguageCode": "en-US",
            "Value": "Gender",
            "IsDefault": true
          },
          {
            "LanguageCode": "id-ID",
            "Value": "Jenis Kelamin",
            "IsDefault": false
          }
        ],
        "Type": "DropdownUnit",
        "DisplayOrder": 9,
        "Editable": true,
        "Mandatory": false,
        "Hidden": true,
        "TopLevelMappingId": 0,
        "Masked": false
      },
      {
        Value: convertTimestampToDOB(Number(birthDate)),
        DefaultValue: null,
        ValidationLogic: [
          {
            Regex:
              "^(0[1-9]|[12][0-9]|3[01])(\\/)(((0)[1-9])|((1)[0-2]))(\\/)\\d{4}$",
            ErrorMessage: [
              {
                LanguageCode: "en-US",
                Description: "15/01/2000",
                Value:
                  "Oops! It looks like you entered the date in the wrong format. 📅 Please use DD/MM/YYYY.",
              },
            ],
            AssociationValue: null,
          },
        ],
        MappingId: 13,
        Name: [
          {
            LanguageCode: "en-US",
            Value: "When were you born?",
            IsDefault: true,
          },
          {
            LanguageCode: "id-ID",
            Value: "Kapan Anda lahir?",
            IsDefault: false,
          },
        ],
        Type: "TextfieldUnit",
        DisplayOrder: 8,
        Editable: true,
        Mandatory: false,
        Hidden: true,
        TopLevelMappingId: 0,
        Masked: false,
      },
      {
        Value: linkedIn,
        DefaultValue: null,
        ValidationLogic: [
          {
            Regex: null,
            ErrorMessage: [
              {
                LanguageCode: "en-US",
                Description: "https://www.linkedin.com/in/dinhlongpham/",
                Value: "P",
              },
            ],
            AssociationValue: null,
          },
        ],
        MappingId: 14,
        Name: [
          {
            LanguageCode: "en-US",
            Value: "Linkedin Profile Link",
            IsDefault: true,
          },
        ],
        Type: "TextfieldUnit",
        DisplayOrder: 13,
        Editable: true,
        Mandatory: false,
        Hidden: true,
        TopLevelMappingId: 0,
        Masked: false,
      },
      {
        Values: lnobTypesArray,
        "DefaultValues": null,
        "PossibleValuesFileUri": null,
        "NumberPossibleValues": 9,
        "PossibleValues": [
          {
            "associationValue": null,
            "value": "Women"
          },
          {
            "associationValue": null,
            "value": "LGBTQIA+"
          },
          {
            "associationValue": null,
            "value": "Out-of-school"
          },
          {
            "associationValue": null,
            "value": "Youth affected by crises (disasters or conflict)"
          },
          {
            "associationValue": null,
            "value": "Religious minority"
          },
          {
            "associationValue": null,
            "value": "Ethnic minority (including Indigenous Peoples)"
          },
          {
            "associationValue": null,
            "value": "Differently-abled (People with Disabilities)"
          },
          {
            "associationValue": null,
            "value": "Low-income"
          },
          {
            "associationValue": null,
            "value": "Not in the list"
          }
        ],
        "MappingId": 11,
        "Name": [
          {
            "LanguageCode": "en-US",
            "Value": "Do you consider yourself to be part of a marginalised disadvantaged or vulnerable group? If yes please specify how (select all that apply); if no please select 'No'",
            "IsDefault": true
          }
        ],
        "Type": "MultiselectUnit",
        "DisplayOrder": 10,
        "Editable": true,
        "Mandatory": false,
        "Hidden": true,
        "TopLevelMappingId": 0,
        "Masked": false
      },
      {
        Values: mctLearningArray,
        "DefaultValues": null,
        "PossibleValuesFileUri": null,
        "NumberPossibleValues": 8,
        "PossibleValues": [
          {
            "associationValue": null,
            "value": "Developer"
          },
          {
            "associationValue": null,
            "value": "Administrative Professional"
          },
          {
            "associationValue": null,
            "value": "Digital Marketer"
          },
          {
            "associationValue": null,
            "value": "I want to explore all the learning pathways on my own!"
          },
          {
            "associationValue": null,
            "value": "Project Manager"
          },
          {
            "associationValue": null,
            "value": "Data Analyst"
          },
          {
            "associationValue": null,
            "value": "Green Jobs"
          },
          {
            "associationValue": null,
            "value": "Freelancing"
          },
          {
            "associationValue": null,
            "value": "Employability"
          },
          {
            "associationValue": null,
            "value": "Other"
          }
        ],
        "MappingId": 24,
        "Name": [
          {
            "LanguageCode": "en-US",
            "Value": "Which learning pathway are you interested in?",
            "IsDefault": true
          }
        ],
        "Type": "MultiselectUnit",
        "DisplayOrder": 16,
        "Editable": true,
        "Mandatory": false,
        "Hidden": true,
        "TopLevelMappingId": 0,
        "Masked": false
      },
      {
        Value: country,
        DefaultValue: null,
        ValidationLogic: [],
        MappingId: 21,
        Name: [
          {
            LanguageCode: "en-US",
            Value: "Which Country are you from?",
            IsDefault: true,
          },
        ],
        Type: "TextfieldUnit",
        DisplayOrder: 18,
        Editable: true,
        Mandatory: false,
        Hidden: false,
        TopLevelMappingId: 0,
        Masked: false,
      },
      {
        Value: city,
        DefaultValue: null,
        ValidationLogic: [],
        MappingId: 15,
        Name: [
          {
            LanguageCode: "en-US",
            Value: "Which city are you from?",
            IsDefault: true,
          },
        ],
        Type: "TextfieldUnit",
        DisplayOrder: 12,
        Editable: true,
        Mandatory: false,
        Hidden: true,
        TopLevelMappingId: 0,
        Masked: false,
      },
      {
        Values: mct_channels,
        "DefaultValues": null,
        "PossibleValuesFileUri": null,
        "NumberPossibleValues": 7,
        "PossibleValues": [
          {
            "associationValue": null,
            "value": "Social media"
          },
          {
            "associationValue": null,
            "value": "Friends"
          },
          {
            "associationValue": null,
            "value": "Local organization"
          },
          {
            "associationValue": null,
            "value": "School"
          },
          {
            "associationValue": null,
            "value": "Government"
          },
          {
            "associationValue": null,
            "value": "Other"
          },
          {
            "associationValue": null,
            "value": "Test New Pathway Phillipines"
          }
        ],
        "MappingId": 26,
        "Name": [
          {
            "LanguageCode": "en-US",
            "Value": "Source",
            "IsDefault": true
          }
        ],
        "Type": "MultiselectUnit",
        "DisplayOrder": 18,
        "Editable": true,
        "Mandatory": false,
        "Hidden": true,
        "TopLevelMappingId": 0,
        "Masked": false
      },
      {
        Values: [
          consent
        ],
        DefaultValues: null,
        PossibleValuesFileUri: null,
        NumberPossibleValues: 1,
        PossibleValues: [
          {
            associationValue: null,
            value: "true"
          }
        ],
        MappingId: 25,
        Name: [
          {
            LanguageCode: "en-US",
            Value: "Consent",
            IsDefault: true
          }
        ],
        Type: "MultiselectUnit",
        DisplayOrder: 17,
        Editable: true,
        Mandatory: false,
        Hidden: false,
        TopLevelMappingId: 0,
        Masked: false
      },
      {
        "Value": createdDate,
        "DefaultValue": null,
        "ValidationLogic": [],
        "MappingId": 29,
        "Name": [
          {
            "LanguageCode": "en-US",
            "Value": "Created Date (Hubspot)",
            "IsDefault": true
          }
        ],
        "Type": "TextfieldUnit",
        "DisplayOrder": 20,
        "Editable": true,
        "Mandatory": false,
        "Hidden": true,
        "TopLevelMappingId": 0,
        "Masked": false
      },
      {
        "Value": university,
        "DefaultValue": null,
        "ValidationLogic": [],
        "MappingId": 31,
        "Name": [
          {
            "LanguageCode": "en-US",
            "Value": "University",
            "IsDefault": true
          }
        ],
        "Type": "TextfieldUnit",
        "DisplayOrder": 18,
        "Editable": true,
        "Mandatory": false,
        "Hidden": false,
        "TopLevelMappingId": 0,
        "Masked": false
      },
      {
        "Value": referralPartner,
        "DefaultValue": null,
        "ValidationLogic": [],
        "MappingId": 32,
        "Name": [
          {
            "LanguageCode": "en-US",
            "Value": "Referral Partner",
            "IsDefault": true
          }
        ],
        "Type": "TextfieldUnit",
        "DisplayOrder": 19,
        "Editable": true,
        "Mandatory": false,
        "Hidden": false,
        "TopLevelMappingId": 0,
        "Masked": false
      }
    ];

    const options = {
      url: `https://${MCT_ENDPT}/api/v2/Organizations/${orgid}/UserProfiles/${userid}`,
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${akey}`,
        ClientType: "service",
      },
      data: structure,
    };

    const response = await axios(options);
    return response.data;
  } catch (error) {
    sendErrorEmail(`Update Error ${email}: ${JSON.stringify(error, null, 4)}`);

    console.log(`Update Error: ${JSON.stringify(error, null, 4)}`);
    throw error;
  }
}
async function lookup_user(akey, email) {
  try {
    const options = {
      url: `https://${MCT_ENDPT}/api/v1/users`,
      method: "GET",
      headers: {
        Authorization: `Bearer ${akey}`,
        ClientType: "service",
      },
      params: {
        searchTerm: email,
      },
    };
    const response = await axios(options);
    return response.data;
  } catch (error) {
    sendErrorEmail(`Error in fetching user: ${email}`);
    throw error;
  }
}


const getContactInfo = async (contactId) => {
  const apiKey = "pat-na1-967cc036-c56e-407f-b84b-4d434f710e7d";
  const url = `https://api.hubapi.com/contacts/v1/contact/vid/${contactId}/profile`;
  const config = {
    headers: {
      Authorization: `Bearer ${apiKey}`,
      clientType: "service",
    },
  };
  try {
    const response = await axios.get(url, config);
    const data = response.data;
    const email = data.properties?.email?.value;
    const formGuid = data["form-submissions"]?.[0]?.["form-id"];
    const pageUrl1 = data['form-submissions'][0]['page-url']; // Assuming this is the URL you want to check
    // Create an object with extracted information
    const result = {
      email: email,
      formGuid: formGuid,
      pageUrl1: pageUrl1,
      cityData: data.properties?.ip_city?.value || '',
      subsData: [formatSubcriptionData(data.properties)],
      createDate: data.properties.createdate ? new Date(parseInt(data.properties.createdate.value)).toISOString() : new Date().toISOString(),
      university1: data.properties['university_philippines']?.value || data.properties['university_indonesia']?.value || data.properties['university_vietnam']?.value || data.properties['school_or_university_openended']?.value || '',
      referralPartner1: data.properties['sof_partners_philippines']?.value || data.properties['sof_partners_indonesia']?.value || data.properties['sof_partners_vietnam']?.value || data.properties['sof_partners_regional']?.value || '',
    };
    console.log("Result", result)
    return result;
  } catch (error) {
    sendErrorEmail("Error in fetching contact info");
    throw error;
  }
};
function formatSubcriptionData(data) {
  let result = [];

  for (let key in data) {
    let value = data[key].value;

    if (value.includes(';')) {
      let values = value.split(';');
      values.forEach(val => {
        result.push({ name: key, value: val });
      });
    } else {
      result.push({ name: key, value: value });
    }
  }

  return { values: result };
}
const getApiKey = async () => {
  const tokenEndpoint = `https://login.microsoft.com/${MCT_TENANT_ID}/oauth2/v2.0/token`;
  const data = `grant_type=client_credentials&client_id=${encodeURIComponent(
    MCT_CLIENT_ID
  )}&scope=${encodeURIComponent(
    `${MCT_API_URI}/.default`
  )}&client_secret=${encodeURIComponent(MCT_CLIENT_SECRET)}`;

  const config = {
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "Content-Length": Buffer.byteLength(data),
    },
  };

  try {
    const response = await axios.post(tokenEndpoint, data, config);
    const tokenData = response.data;

    if (tokenData.access_token) {
      return tokenData.access_token;
    } else {
      throw new Error("Failed to obtain MCT API key.");
    }
  } catch (error) {
    console.error("Error in request:", error);
    throw error;
  }
};

function sendErrorEmail(message) {
  console.log("Error Message", message);
  const grid_mailer = new GridMail()
    .setFrom(SGRID_FROM_EMAIL);
  // Send grid mail
  grid_mailer
    .sendErrorEmail(message).then(res => {
      console.log("Error email is sent")
    });
}
// const PORT = process.env.PORT || 4000;
// app.listen(PORT, () => {
//   console.log(`Server is running on port ${PORT}`);
// });

export const createUser = onRequest(app);
export const scheduledEmailSender = onSchedule("0 * * * *", async (context) => {
  try {
    GridMail.setApiKey(SGRID_API_KEY);
    const now = new Date();
    const emailsSnapshot = await db.collection("emails")
      .where("scheduleDate", "<=", now)
      .where("sent", "==", false)
      .get();

    if (emailsSnapshot.empty) {
      console.log("No scheduled emails to send.");
      return;
    }

    for (const doc of emailsSnapshot.docs) {
      const emailData = doc.data();
      console.log(`Sending email to ${emailData.toEmail}...`);

      try {
        const grid_mailer = new GridMail()
          .setTemplate(emailData.templateId)
          .setFrom(SGRID_FROM_EMAIL)
          .setTo(emailData.toEmail)
          .setTemplateData({
            nickname: emailData.data.nickname,
            password: emailData.data.password,
          });

        await grid_mailer.send();
        console.log(`Email sent to ${emailData.toEmail}`);

        // Mark email as sent
        await db.collection("emails").doc(doc.id).update({ sent: true });
      } catch (error) {
        console.error(`Failed to send email to ${emailData.toEmail}`, error);
      }
    }
  } catch (error) {
    console.error("Error in scheduled email sender:", error);
  }
});