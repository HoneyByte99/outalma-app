# Privacy Policy of Outalma Service

Last updated: 6 September 2026

This policy describes how **KAYZEN TECHNOLOGY** ("we", "us", "our"), publisher of the Outalma Service application, collects, uses and protects your personal data when you use our mobile application and our website (together, the "Application"). Outalma Service is a services marketplace for users based in Senegal. A single account may act as a **customer** (booking services) and as a **provider** (offering services).

We are committed to complying with **Senegalese Law No. 2008-12 of 25 January 2008** on the protection of personal data.


## 1. Identity of the data controller

The data controller is:

- **Company name**: KAYZEN TECHNOLOGY
- **Legal form / registration number**: [to be completed before publication]
- **Registered office address**: [to be completed before publication]
- **Contact email**: contact@outalma.com
- **Data Protection Officer (DPO)**: not designated to date


## 2. Data we collect

We limit collection to the data necessary for the operation of the service.

### 2.1 Identity data
- First name, last name, displayed username
- Profile photo (optional)
- Date of birth (minimum age verification)

### 2.2 Contact data
- Email address
- Phone number (international E.164 format)

Your phone number is **never displayed publicly**. It is made visible only between a customer and a provider **after acceptance of a booking**, in order to facilitate coordination of the service (a model inspired by BlaBlaCar).

### 2.3 User content
- Published service listings (title, description, prices, photos)
- Messages exchanged in chat (text, images, voice messages) between participants of a booking
- Reviews and ratings left after a service

### 2.4 Location data
- Declared address or service area
- Approximate position for searching nearby providers (via Google Maps / Places). Precise geolocation is only used with your explicit consent via the operating system's permissions.

### 2.5 Technical data
- Firebase user identifier
- Device model, operating system version, Application version
- Push notification tokens (Firebase Cloud Messaging)
- Anonymised crash logs (Firebase Crashlytics)
- IP address (transiently, during calls to backend services)


## 3. Purposes of processing

Your data is used to:

1. **Authentication**: create and secure your account via email (magic link) or phone (OTP code).
2. **Provision of the service**: publish listings, search, book, exchange via chat, manage reviews.
3. **Communication**: send you notifications relating to your bookings, messages, or changes to your account.
4. **Security**: detect fraud, abuse, multiple accounts or behaviour prohibited by our Terms of Use.
5. **Service improvement**: fix bugs (via Crashlytics) and improve usability. We use **no third-party behavioural analytics tool**.
6. **Legal compliance**: respond to a legal or regulatory obligation, or to a judicial request.


## 4. Grounds for processing (Law No. 2008-12)

Senegalese Law No. 2008-12 provides that processing your data is lawful where you have given your consent. Its Article 33 allows this consent requirement to be set aside where the processing is necessary to comply with a legal obligation, to perform a task carried out in the public interest, to perform a contract to which you are a party, or to safeguard your interests or fundamental rights and freedoms.

| Purpose | Ground |
|---|---|
| Account creation and performance of bookings | Performance of the contract to which you are a party (Art. 33-3) |
| Push notifications | Consent, revocable at any time from settings |
| Precise geolocation | Consent, obtained via the operating system's permissions |
| Security, fraud prevention | Necessary for the proper functioning of the service and for protecting users against abusive use of the platform |
| Crashlytics (technical diagnostics) | Necessary for the proper functioning of the service |
| Possible accounting and tax retention | Legal obligation (Art. 33-1) |


## 5. Processors and recipients

We **never sell** your data. We display **no advertising** within the Application. Your data is only shared with the technical processors strictly necessary:

| Processor | Role | Server location |
|---|---|---|
| **Google / Firebase** (Auth, Firestore, Cloud Functions, Storage, Cloud Messaging, Crashlytics) | Hosting, authentication, database, file storage, notifications, crash reports | European Union (`europe-west` region) with global Google operations |
| **Twilio Verify** | Sending OTP codes by SMS | United States, Ireland |
| **Google Maps Platform / Places API** | Mapping, address search, distance calculation | Global Google operations |

The other recipients are **the users themselves**: a profile's public information (first name, photo, services offered, reviews) is visible to other users. The phone number is only shared between the two participants of an accepted booking.


## 6. Retention period

| Data | Period |
|---|---|
| Active account | For as long as the account exists |
| Inactive account (no login) | 3 years after last activity, then deletion or anonymisation |
| Chat messages | 2 years after the end of the associated booking |
| Booking history | 5 years (evidence in the event of a dispute) |
| Crash reports (Crashlytics) | 90 days |
| Billing data (where applicable) | 10 years (accounting obligation) |

You may at any time request the deletion of your account from within the Application. Data will be erased unless subject to a legal retention obligation.


## 7. Your rights

In accordance with Senegalese Law No. 2008-12, you have the following rights:

- **Information**: be informed, before or at the time of collection, of the identity of the data controller, the purposes, the recipients and the retention period of your data (Art. 58 to 61)
- **Access**: obtain confirmation that processing concerning you exists, and a copy of your data (Art. 62 to 65)
- **Objection**: object, on legitimate grounds, to processing concerning you, in particular to the disclosure of your data to third parties for prospecting purposes; this right does not apply where the processing meets a legal obligation (Art. 68)
- **Rectification and erasure**: request that inaccurate, incomplete, outdated data, or data whose collection, use, disclosure or retention is prohibited, be rectified, completed, updated, blocked or erased (Art. 69)

To exercise these rights, write to us at: **contact@outalma.com**. Article 69 of Law No. 2008-12 sets a response deadline of **one (1) month** for rectification requests; we apply this same deadline to all such requests. Proof of identity may be requested in case of reasonable doubt.


## 8. Transfers of data outside Senegal

Certain processors (Google, Twilio) may process your data outside Senegal, in particular in the European Union and in the United States (see Section 5).

Under Law No. 2008-12, such a transfer is only possible if the destination State ensures a sufficient level of protection for the privacy and fundamental rights of the individuals concerned (Art. 49). Failing that, the transfer remains possible if it is occasional, not massive, and the individual concerned has expressly consented to it, or in one of the cases provided for in Article 50, or where the Commission des Données Personnelles authorises it because the data controller offers sufficient guarantees (Art. 51).

We apply additional technical security measures (encryption in transit and at rest) to all of these transfers.

**[to be verified before publication]**: whether the prior step with the Commission des Données Personnelles required by Article 49 for these transfers (prior information, or, as the case may be, a request for authorisation under Article 51) has been completed has not been confirmed to date.


## 9. Data security

We implement reasonable technical and organisational measures:

- TLS encryption for all client / server communications
- Encryption at rest of data stored with Firebase
- Strong authentication (magic link or OTP code, with no password to remember)
- Firestore and Storage security rules restricting access to authorised persons only
- Access logs and alerts in the event of suspicious activity
- Access to data restricted to the only team members who need it

As no system is infallible, we make a contractual commitment (Law No. 2008-12 does not set a specific figure in this regard) to notify you of any data breach likely to result in a high risk to your rights, within **72 hours** of becoming aware of it.


## 10. Cookies and trackers (website)

The web version of Outalma uses only:

- **strictly necessary cookies** for operation (session, authentication, language preferences),
- technical cookies set by Firebase Hosting and Firebase Auth.

We use **no advertising cookie, no tracking pixel, no third-party analytics tracker** beyond Firebase Crashlytics (which does not set a browser-side cookie).

No consent banner is therefore required for non-essential cookies, since we do not set any. You may delete cookies at any time from your browser's settings.


## 11. Minors' data

The Application is reserved for persons aged at least **16 years**. We do not knowingly collect data concerning minors under 16. If you believe that a minor under 16 has provided us with data, contact us: we will delete the account concerned.


## 12. Amendment of the policy

This policy may evolve over time (new features, change of processor, legal developments). Any substantial amendment will be notified to you within the Application and/or by email, at least **15 days before** it takes effect, so as to allow you to exercise your rights.

The date at the top of this document always indicates the version in force.


## 13. Contact and complaints

For any question relating to your personal data:

- **Email**: contact@outalma.com
- **Postal address**: KAYZEN TECHNOLOGY [address to be completed before publication]

If you believe that your rights are not being respected, you may lodge a complaint with the **Commission des Données Personnelles (CDP)**: Complexe SICAP, Point E, 1st floor, Immeuble A, Avenue Cheikh Anta Diop x Canal IV, Dakar, Senegal. Website: [www.cdp.sn](https://www.cdp.sn)


## 14. Effective date

This policy has been in force since **6 September 2026**.


## 15. Governing language

This policy is drawn up in French and in English. In the event of any discrepancy or inconsistency between the two versions, the **French version shall prevail**; the English version is provided for information purposes only.
